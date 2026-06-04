/// Constantes globales de l'application VisionX.
class AppConstants {
  AppConstants._();

  // ── Clés SharedPreferences ───────────────────────────────────
  static const String prefLanguage = 'selected_language';
  static const String prefConfThreshold = 'confidence_threshold';
  static const String prefFirstLaunch = 'first_launch';

  // ── Valeurs par défaut ───────────────────────────────────────
  static const double defaultConfThreshold = 0.5;
  static const int maxDetections = 10;

  // ── Timings animations ───────────────────────────────────────
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration bbAnimDuration = Duration(milliseconds: 150);

  // ── Modèle TFLite ────────────────────────────────────────────
  static const int inputSize = 300; // taille d'entrée du modèle (px)
  static const int numResults = 10;
}
