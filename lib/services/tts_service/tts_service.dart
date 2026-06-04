import 'package:flutter_tts/flutter_tts.dart';
import '../../services/model_manager/model_manager.dart';

/// Service Text-to-Speech lié à la langue du modèle actif.
///
/// Pour l'Ewe : aucune locale standard n'est disponible.
/// Lorsqu'un moteur TTS custom sera intégré (ex. Coqui TTS via HTTP),
/// il suffira de brancher [_speakCustom] ici sans toucher le reste de l'app.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> initialize() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Lit [text] dans la langue du modèle actif.
  Future<void> speak(String text) async {
    if (!_initialized) await initialize();

    final locale = ModelManager.instance.currentModel.ttsLocale;
    if (locale == null) {
      // Ewe ou langue sans TTS standard : fallback silencieux.
      // TODO: appel HTTP vers moteur TTS custom Ewe.
      return;
    }

    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stop() async => _tts.stop();

  void dispose() => _tts.stop();
}
