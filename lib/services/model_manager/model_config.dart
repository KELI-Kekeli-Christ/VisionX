import '../../domain/entities/language_model.dart';

/// Registre centralisé de tous les modèles linguistiques.
/// Pour ajouter une langue : ajouter une entrée ici, c'est tout.
class ModelConfig {
  ModelConfig._();

  // SSD MobileNet V1 COCO — metadata V2 (entrée 300×300, float32 [0,1])
  // Sorties standard : boxes[1,10,4] | classes[1,10] | scores[1,10] | count[1]
  static const _enModelUrl =
      'https://github.com/tensorflow/flutter-tflite'
      '/raw/main/example/lib/object_detection/assets/ssd_mobilenet.tflite';

  static const List<LanguageModel> all = [
    LanguageModel(
      code: 'en',
      displayName: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
      modelAssetPath: 'assets/models/detect_en.tflite',
      labelsAssetPath: 'assets/labels/labels_en.txt',
      status: ModelStatus.active,
      ttsLocale: 'en-US',
      downloadUrl: _enModelUrl,
    ),
    LanguageModel(
      code: 'fr',
      displayName: 'Français',
      nativeName: 'Français',
      flag: '🇫🇷',
      modelAssetPath: 'assets/models/detect_fr.tflite',
      labelsAssetPath: 'assets/labels/labels_fr.txt',
      status: ModelStatus.comingSoon,
      ttsLocale: 'fr-FR',
      downloadUrl: null,
    ),
    LanguageModel(
      code: 'ewe',
      displayName: 'Ewe',
      nativeName: 'Èvègbe',
      flag: '🇹🇬',
      modelAssetPath: 'assets/models/detect_ewe.tflite',
      labelsAssetPath: 'assets/labels/labels_ewe.txt',
      status: ModelStatus.comingSoon,
      ttsLocale: null,
      downloadUrl: null,
    ),
  ];

  static LanguageModel get defaultModel =>
      all.firstWhere((m) => m.code == 'en');

  static LanguageModel? byCode(String code) {
    try {
      return all.firstWhere((m) => m.code == code);
    } catch (_) {
      return null;
    }
  }
}
