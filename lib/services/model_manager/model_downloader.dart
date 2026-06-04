import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/language_model.dart';

/// Télécharge et met en cache les fichiers .tflite dans le répertoire
/// documents de l'application.
///
/// Priorité de chargement :
///   1. Cache local dans [_modelsDir] (téléchargé précédemment)
///   2. Asset bundlé dans `assets/models/`
///   3. Téléchargement depuis [LanguageModel.downloadUrl]
class ModelDownloader {
  ModelDownloader._();

  static Future<String> get _modelsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/visionx_models');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir.path;
  }

  static String _filename(LanguageModel model) =>
      'detect_${model.code}.tflite';

  /// Retourne le chemin local si le fichier est déjà en cache.
  static Future<String?> cachedPath(LanguageModel model) async {
    final dir = await _modelsDir;
    final file = File('$dir/${_filename(model)}');
    // Vérifie que le fichier a une taille raisonnable (> 500 KB)
    if (file.existsSync() && file.lengthSync() > 512 * 1024) {
      return file.path;
    }
    return null;
  }

  /// Télécharge le modèle avec progress callback.
  /// Retourne le chemin local ou null en cas d'échec.
  static Future<String?> download(
    LanguageModel model, {
    void Function(double progress)? onProgress,
  }) async {
    final url = model.downloadUrl;
    if (url == null) return null;

    final dir = await _modelsDir;
    final file = File('$dir/${_filename(model)}');

    // Déjà en cache valide
    if (file.existsSync() && file.lengthSync() > 512 * 1024) {
      return file.path;
    }

    debugPrint('[ModelDownloader] GET $url');

    try {
      // http.get() suit automatiquement les redirects (CDN, GitHub, TFHub)
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        debugPrint('[ModelDownloader] HTTP ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.length < 512 * 1024) {
        debugPrint('[ModelDownloader] File too small (${bytes.length} B)');
        return null;
      }

      await file.writeAsBytes(bytes);
      onProgress?.call(1.0);
      debugPrint('[ModelDownloader] Saved ${file.path} '
          '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)');
      return file.path;
    } catch (e) {
      debugPrint('[ModelDownloader] Error: $e');
      if (file.existsSync()) await file.delete();
      return null;
    }
  }

  /// Supprime le cache pour forcer un re-téléchargement.
  static Future<void> evict(LanguageModel model) async {
    final dir = await _modelsDir;
    final file = File('$dir/${_filename(model)}');
    if (file.existsSync()) await file.delete();
  }
}
