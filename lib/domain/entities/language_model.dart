/// Statut de disponibilité d'un modèle linguistique.
enum ModelStatus {
  /// Modèle actif et chargé.
  active,

  /// Modèle en cours de téléchargement / chargement.
  loading,

  /// Modèle prévu mais pas encore disponible (UI grisée).
  comingSoon,
}

/// Configuration d'un modèle de détection pour une langue donnée.
class LanguageModel {
  const LanguageModel({
    required this.code,
    required this.displayName,
    required this.nativeName,
    required this.flag,
    required this.modelAssetPath,
    required this.labelsAssetPath,
    required this.status,
    this.ttsLocale,
    this.downloadUrl,
  });

  final String code;
  final String displayName;

  /// Nom dans la langue elle-même (ex: "Èvègbe" pour l'Ewe).
  final String nativeName;

  final String flag;

  /// Chemin asset bundlé (.tflite) — fallback si le fichier local n'existe pas.
  final String modelAssetPath;

  final String labelsAssetPath;
  final ModelStatus status;

  /// Locale BCP-47 pour le TTS (null = moteur custom requis).
  final String? ttsLocale;

  /// URL de téléchargement du modèle .tflite (null = non disponible).
  final String? downloadUrl;

  bool get isAvailable => status == ModelStatus.active;
  bool get isComingSoon => status == ModelStatus.comingSoon;
}
