import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/language_model.dart';
import 'model_config.dart';
import 'model_downloader.dart';

/// Gère le cycle de vie des modèles TFLite et des fichiers de labels.
///
/// Priorité de chargement : cache local → asset bundlé → téléchargement.
///
/// Usage :
///   await ModelManager.instance.initialize();
///   await ModelManager.instance.switchTo('fr');
///   final results = await manager.runInference(float32Tensor);
class ModelManager {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  Interpreter? _interpreter;
  List<String> _labels = [];
  LanguageModel _current = ModelConfig.defaultModel;
  bool _initialized = false;

  LanguageModel get currentModel => _current;
  bool get isInitialized => _initialized;

  // ── Initialisation ─────────────────────────────────────────

  Future<void> initialize({void Function(double)? onProgress}) async {
    await _load(ModelConfig.defaultModel, onProgress: onProgress);
    _initialized = _interpreter != null;
  }

  // ── Changement de langue ───────────────────────────────────

  Future<bool> switchTo(String languageCode) async {
    final target = ModelConfig.byCode(languageCode);
    if (target == null || !target.isAvailable) return false;
    if (target.code == _current.code && _interpreter != null) return true;

    await _load(target);
    return _interpreter != null;
  }

  // ── Inférence réelle ───────────────────────────────────────

  /// [inputTensor] : Float32List de taille inputSize × inputSize × 3,
  /// valeurs normalisées [0.0, 1.0], canal RGB.
  ///
  /// Compatible SSD MobileNet V1/V2 COCO (sorties standard à 4 tenseurs).
  Future<List<DetectionResult>> runInference(Float32List inputTensor) async {
    if (_interpreter == null || _labels.isEmpty) return const [];

    final sz = AppConstants.inputSize;
    // Vérification de cohérence
    assert(inputTensor.length == sz * sz * 3,
        'Tensor size mismatch: expected ${sz * sz * 3}, got ${inputTensor.length}');

    // ── Pré-allocation des buffers de sortie ──────────────────
    // SSD MobileNet V1/V2 : 10 détections max par défaut
    const maxDet = AppConstants.numResults;
    final outputLocations =
        List.generate(1, (_) => List.generate(maxDet, (_) => List.filled(4, 0.0)));
    final outputClasses =
        List.generate(1, (_) => List.filled(maxDet, 0.0));
    final outputScores =
        List.generate(1, (_) => List.filled(maxDet, 0.0));
    final outputCount = List.filled(1, 0.0);

    // ── Passage en bytes bruts pour l'interpréteur ────────────
    // Float32List.buffer.asUint8List() = représentation IEEE 754 exacte
    final inputBytes = inputTensor.buffer.asUint8List();

    final inputs = [inputBytes];
    final outputs = <int, Object>{
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    };

    try {
      _interpreter!.runForMultipleInputs(inputs, outputs);
    } catch (e) {
      // Certains modèles nécessitent l'entrée en List imbriquée
      return _runWithNestedInput(inputTensor, sz, maxDet);
    }

    return _parseOutputs(
      outputLocations,
      outputClasses,
      outputScores,
      outputCount[0].toInt(),
    );
  }

  // ── Fallback : entrée en liste imbriquée ────────────────────

  List<DetectionResult> _runWithNestedInput(
    Float32List flat,
    int sz,
    int maxDet,
  ) {
    // Reconstruit [1][sz][sz][3] — utilisé si le modèle rejette Uint8List
    final input = List.generate(
      1,
      (_) => List.generate(
        sz,
        (y) => List.generate(
          sz,
          (x) => List.generate(3, (c) => flat[y * sz * 3 + x * 3 + c]),
        ),
      ),
    );

    final outputLocations =
        List.generate(1, (_) => List.generate(maxDet, (_) => List.filled(4, 0.0)));
    final outputClasses = List.generate(1, (_) => List.filled(maxDet, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(maxDet, 0.0));
    final outputCount = List.filled(1, 0.0);

    final outputs = <int, Object>{
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    };

    try {
      _interpreter!.runForMultipleInputs([input], outputs);
    } catch (e) {
      return const [];
    }

    return _parseOutputs(
      outputLocations,
      outputClasses,
      outputScores,
      outputCount[0].toInt(),
    );
  }

  // ── Parsing des tenseurs de sortie ─────────────────────────

  List<DetectionResult> _parseOutputs(
    List outputLocations,
    List outputClasses,
    List outputScores,
    int count,
  ) {
    final results = <DetectionResult>[];
    final clampedCount = count.clamp(0, AppConstants.numResults);

    for (int i = 0; i < clampedCount; i++) {
      final score = (outputScores[0][i] as num).toDouble();
      if (score < 0.3) continue;

      final classId = (outputClasses[0][i] as num).toInt();
      final label = classId < _labels.length ? _labels[classId] : 'Unknown';

      final box = outputLocations[0][i] as List;
      // Format TFLite SSD : [ymin, xmin, ymax, xmax] normalisés
      final ymin = (box[0] as num).toDouble().clamp(0.0, 1.0);
      final xmin = (box[1] as num).toDouble().clamp(0.0, 1.0);
      final ymax = (box[2] as num).toDouble().clamp(0.0, 1.0);
      final xmax = (box[3] as num).toDouble().clamp(0.0, 1.0);

      results.add(DetectionResult(
        classId: classId,
        label: label,
        confidence: score,
        boundingBox: Rect.fromLTRB(xmin, ymin, xmax, ymax),
      ));
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  // ── Chargement interne ─────────────────────────────────────

  Future<void> _load(
    LanguageModel model, {
    void Function(double)? onProgress,
  }) async {
    _interpreter?.close();
    _interpreter = null;

    // 1. Asset bundlé (priorité si modèle inclus dans l'APK via pubspec)
    _interpreter ??= await _tryLoadAsset(model.modelAssetPath);

    // 2. Fichier local préalablement téléchargé
    if (_interpreter == null) {
      final localPath = await ModelDownloader.cachedPath(model);
      if (localPath != null) {
        _interpreter = _tryLoadFile(localPath);
      }
    }

    // 3. Téléchargement automatique si toujours absent
    if (_interpreter == null && model.downloadUrl != null) {
      debugPrint('[ModelManager] Downloading model for ${model.code}…');
      final downloaded = await ModelDownloader.download(
        model,
        onProgress: onProgress,
      );
      if (downloaded != null) {
        _interpreter = _tryLoadFile(downloaded);
      }
    }

    if (_interpreter == null) {
      debugPrint('[ModelManager] ⚠ No model found for ${model.code}');
    } else {
      debugPrint('[ModelManager] ✓ ${model.code} loaded '
          '— input shape: ${_interpreter!.getInputTensor(0).shape} '
          '— output tensors: ${_interpreter!.getOutputTensors().length}');
    }

    _labels = await _loadLabels(model.labelsAssetPath);
    debugPrint('[ModelManager] Labels: ${_labels.length} classes');
    _current = model;
  }

  Interpreter? _tryLoadFile(String path) {
    try {
      return Interpreter.fromFile(File(path));
    } catch (e) {
      debugPrint('[ModelManager] fromFile failed: $e');
      return null;
    }
  }

  Future<Interpreter?> _tryLoadAsset(String assetPath) async {
    try {
      return await Interpreter.fromAsset(assetPath);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _loadLabels(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
    } catch (e) {
      debugPrint('[ModelManager] Labels load failed: $e');
      return const [];
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}
