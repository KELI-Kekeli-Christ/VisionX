import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/language_model.dart';
import '../../services/camera_service/camera_service.dart';
import '../../services/camera_service/image_utils.dart';
import '../../services/model_manager/model_config.dart';
import '../../services/model_manager/model_manager.dart';
import '../../services/tts_service/tts_service.dart';

/// ViewModel MVVM — orchestre caméra → prétraitement → inférence TFLite.
///
/// Pipeline réel :
///   1. CameraImage → CameraFrameData (main thread)
///   2. compute(preprocessFrameData)  → Float32List (isolate)
///   3. ModelManager.runInference()   → détections (main thread)
///   4. notifyListeners()             → UI
class DetectionProvider extends ChangeNotifier {
  DetectionProvider() {
    _init();
  }

  // ── État ────────────────────────────────────────────────────
  List<DetectionResult> _detections = const [];
  double _confidenceThreshold = AppConstants.defaultConfThreshold;
  bool _isRunning = false;
  bool _cameraReady = false;
  bool _isSwitchingModel = false;
  bool _modelReady = false;
  bool _modelFailed = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0.0;
  String _selectedLanguageCode = 'en';

  // Throttle : 1 inférence max toutes les 100 ms (≈ 10 fps)
  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  bool _inferenceInProgress = false;

  // ── Getters ─────────────────────────────────────────────────
  List<DetectionResult> get detections => _detections;
  double get confidenceThreshold => _confidenceThreshold;
  bool get isRunning => _isRunning;
  bool get cameraReady => _cameraReady;
  bool get isSwitchingModel => _isSwitchingModel;
  bool get modelReady => _modelReady;
  bool get modelFailed => _modelFailed;
  bool get isDownloadingModel => _isDownloadingModel;
  double get downloadProgress => _downloadProgress;
  String get selectedLanguageCode => _selectedLanguageCode;
  List<LanguageModel> get availableModels => ModelConfig.all;
  LanguageModel get currentModel => ModelManager.instance.currentModel;

  // ── Initialisation ──────────────────────────────────────────

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _confidenceThreshold =
        prefs.getDouble(AppConstants.prefConfThreshold) ??
            AppConstants.defaultConfThreshold;
    _selectedLanguageCode =
        prefs.getString(AppConstants.prefLanguage) ?? 'en';

    // Caméra + modèle en parallèle
    await Future.wait([
      _initCamera(),
      _initModel(),
    ]);
  }

  Future<void> _initCamera() async {
    await CameraService.instance.initialize();
    _cameraReady = CameraService.instance.isInitialized;
    notifyListeners();
    await TtsService.instance.initialize();
    if (_cameraReady) await startDetection();
  }

  Future<void> _initModel() async {
    _isDownloadingModel = true;
    notifyListeners();

    await ModelManager.instance.initialize(
      onProgress: (p) {
        _downloadProgress = p;
        notifyListeners();
      },
    );

    _isDownloadingModel = false;
    _modelReady = ModelManager.instance.isInitialized;
    _modelFailed = !_modelReady;
    notifyListeners();

    if (_modelReady) {
      debugPrint('[DetectionProvider] Model ready — ${currentModel.code}');
    } else {
      debugPrint('[DetectionProvider] Model failed to load');
    }
  }

  // ── Contrôle du flux ────────────────────────────────────────

  Future<void> startDetection() async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();
    await CameraService.instance.startStream(_onCameraFrame);
  }

  Future<void> stopDetection() async {
    await CameraService.instance.stopStream();
    _isRunning = false;
    _detections = const [];
    notifyListeners();
  }

  // ── Réception d'une frame ───────────────────────────────────

  void _onCameraFrame(CameraImage image) {
    // Pas de modèle → rien à faire (caméra continue de s'afficher)
    if (!_modelReady) return;

    final now = DateTime.now();
    if (_inferenceInProgress ||
        now.difference(_lastInference).inMilliseconds < 100) {
      return;
    }
    _inferenceInProgress = true;
    _lastInference = now;
    _runPipeline(image);
  }

  // ── Pipeline caméra → TFLite ────────────────────────────────

  Future<void> _runPipeline(CameraImage image) async {
    try {
      // 1. Extraire bytes (synchrone, main thread)
      final frameData = CameraFrameData.fromCameraImage(
        image,
        AppConstants.inputSize,
      );
      if (frameData == null) {
        debugPrint('[DetectionProvider] Unsupported image format: '
            '${image.format.group}');
        return;
      }

      // 2. YUV/BGRA → Float32 normalisé (isolate)
      final tensor = await compute(preprocessFrameData, frameData);

      // 3. Inférence TFLite (main thread — l'interpréteur n'est pas isolate-safe)
      final raw = await ModelManager.instance.runInference(tensor);

      // 4. Filtre + limite
      _detections = raw
          .where((d) => d.confidence >= _confidenceThreshold)
          .take(AppConstants.maxDetections)
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('[DetectionProvider] Pipeline error: $e');
    } finally {
      _inferenceInProgress = false;
    }
  }

  // ── Changement de langue ────────────────────────────────────

  Future<void> selectLanguage(String code) async {
    final model = ModelConfig.byCode(code);
    if (model == null || !model.isAvailable) return;
    if (code == _selectedLanguageCode) return;

    _isSwitchingModel = true;
    notifyListeners();

    await stopDetection();
    final ok = await ModelManager.instance.switchTo(code);

    if (ok) {
      _selectedLanguageCode = code;
      _modelReady = true;
      _modelFailed = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefLanguage, code);
    }

    _isSwitchingModel = false;
    notifyListeners();
    await startDetection();
  }

  // ── Retry après échec ───────────────────────────────────────

  Future<void> retryModelDownload() async {
    _modelFailed = false;
    notifyListeners();
    await _initModel();
  }

  // ── Seuil de confiance ──────────────────────────────────────

  void setConfidenceThreshold(double value) {
    _confidenceThreshold = value;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(AppConstants.prefConfThreshold, value));
  }

  // ── TTS on tap ──────────────────────────────────────────────

  void speakDetection(DetectionResult d) {
    TtsService.instance.speak(d.label);
  }

  // ── Flip caméra ─────────────────────────────────────────────

  Future<void> flipCamera() async {
    await stopDetection();
    await CameraService.instance.flipCamera();
    await startDetection();
  }

  @override
  void dispose() {
    stopDetection();
    TtsService.instance.dispose();
    super.dispose();
  }
}
