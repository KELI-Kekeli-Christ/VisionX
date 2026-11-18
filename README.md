<p align="center">
  <a href="README.md"><b>English</b></a>
  &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a>
  &nbsp;·&nbsp;
  <a href="README.es.md">Español</a>
</p>

# VisionX

**Détection d'objets en temps réel · Multilingue · On-device**

Application mobile Flutter de vision par ordinateur tournant entièrement **sans serveur, sans internet**, avec une architecture modulaire prête à accueillir de nouveaux modèles de langues (FR, EWE…) sans réécrire une seule ligne d'interface.

---

## Fonctionnalités

- Flux caméra **plein écran edge-to-edge**, rendu natif sans dégradation
- **Bounding boxes** élégantes — coins L-shape, effet de lueur, label + score de confiance
- **Sélecteur de langue flottant** — langues non disponibles grisées avec badge « Soon »
- **Seuil de confiance** ajustable en temps réel (Bottom Sheet)
- **Text-to-Speech** — tap sur un objet détecté pour l'entendre lire
- Téléchargement automatique du modèle au premier lancement si absent
- Onboarding animé au premier démarrage
- **0 cloud** — toute l'inférence est locale, 0 donnée envoyée

---

## Langues

| Code | Langue | Statut | Modèle |
|------|--------|--------|--------|
| `en` | 🇬🇧 English | ✅ Actif | SSD MobileNet V1 COCO |
| `fr` | 🇫🇷 Français | ⏳ À venir | — |
| `ewe` | 🇹🇬 Èvègbe | ⏳ À venir | — |

---

## Architecture

```
lib/
├── core/
│   ├── constants/      AppConstants — seuils, timings, taille modèle
│   └── theme/          AppTheme — palette sombre Glassmorphism
│
├── domain/
│   └── entities/
│       ├── DetectionResult     classId · label · confidence · Rect
│       └── LanguageModel       code · status · downloadUrl · ttsLocale
│
├── services/
│   ├── model_manager/
│   │   ├── ModelConfig         registre centralisé EN / FR / EWE
│   │   ├── ModelManager        chargement, switch, inférence TFLite
│   │   └── ModelDownloader     cache local + téléchargement HTTP
│   ├── camera_service/
│   │   ├── CameraService       CameraController, flip, stream
│   │   └── image_utils         YUV420 / BGRA8888 → Float32 (isolate)
│   └── tts_service/
│       └── TtsService          TTS BCP-47, fallback silencieux pour l'Ewe
│
└── presentation/
    ├── providers/
    │   └── DetectionProvider   ViewModel MVVM — pipeline caméra → UI
    ├── screens/
    │   ├── splash/             logo animé + halo pulsant
    │   ├── onboarding/         3 pages PageView
    │   └── camera/             écran principal
    └── widgets/
        ├── BoundingBoxPainter  CustomPainter 100 % canvas, zéro widget
        ├── LanguageSelector    pill flottant avec badge « Soon »
        └── SettingsBottomSheet slider confiance + info modèle
```

### Pipeline d'inférence

```
CameraImage  (main thread)
     │
     ▼  CameraFrameData.fromCameraImage()    ← extraction bytes, synchrone
     │
     ▼  compute(preprocessFrameData)         ← isolate Dart
        YUV420 BT.601 → RGB → resize 300×300 → Float32 normalisé [0,1]
     │
     ▼  ModelManager.runInference()          ← main thread (TFLite non isolate-safe)
        runForMultipleInputs([bytes], {boxes, classes, scores, count})
     │
     ▼  DetectionProvider.notifyListeners()
     │
     ▼  BoundingBoxPainter (CustomPaint sur RepaintBoundary)
```

---

## Installation

### Prérequis

- [Flutter ≥ 3.35](https://flutter.dev/docs/get-started)
- Android SDK ≥ API 21 (Android 5.0)
- Un **device physique** Android (la caméra ne fonctionne pas sur émulateur)

### 1. Cloner et installer les dépendances

```bash
git clone <url-du-repo>
cd video_app
flutter pub get
```

### 2. Télécharger le modèle EN

```bash
bash scripts/download_model.sh
```

Ce script télécharge **SSD MobileNet V1 COCO quantisé** (~4 MB) depuis Google Storage
et le place dans `assets/models/detect_en.tflite`.

> Si le modèle est absent des assets et que l'appareil est connecté à internet,
> l'application le télécharge automatiquement au premier lancement
> et affiche une barre de progression.

### 3. Connecter le device et lancer

```bash
flutter run
```

---

## Ajouter une nouvelle langue

L'ajout d'un nouveau modèle de langue se fait en **3 étapes**,
sans modifier une seule ligne de l'interface.

### Étape 1 — Préparer le fichier de labels

Créer `assets/labels/labels_fr.txt` (une classe par ligne, encodage UTF-8) :

```
personne
vélo
voiture
moto
...
```

> Pour l'Ewe, inclure les caractères spéciaux de l'alphabet :
> `ɖ ƒ ɣ ŋ ɔ ʋ Ɖ Ƒ Ɣ Ŋ Ɔ Ʋ` et les marques tonales `à á ā ǎ`.
> Les lignes commençant par `#` sont ignorées au chargement.

### Étape 2 — Déposer le modèle

Copier le fichier `.tflite` entraîné dans `assets/models/detect_fr.tflite`.

Le modèle doit respecter l'interface SSD standard :

| Tenseur | Forme | Type |
|---------|-------|------|
| Entrée | `[1, 300, 300, 3]` | float32 normalisé [0, 1] |
| Sortie 0 — boxes | `[1, N, 4]` ymin·xmin·ymax·xmax | float32 |
| Sortie 1 — classes | `[1, N]` | float32 |
| Sortie 2 — scores | `[1, N]` | float32 |
| Sortie 3 — count | `[1]` | float32 |

### Étape 3 — Activer dans ModelConfig

Dans `lib/services/model_manager/model_config.dart`,
changer **une seule ligne** pour la langue ciblée :

```dart
// Avant
status: ModelStatus.comingSoon,

// Après
status: ModelStatus.active,
```

**C'est tout.** Le sélecteur de langue, le TTS et les bounding boxes
s'adaptent automatiquement à la langue active.

---

## Spécificités langue Ewe (Èvègbe)

### Fichier de labels

```
# labels_ewe.txt — encodage UTF-8 obligatoire
# Format : une classe par ligne, index implicite
ame          → personne
gōlō         → voiture  (ton macron)
ƒometo       → réfrigérateur  (lettre Ƒ)
```

### Text-to-Speech

Il n'existe pas de locale TTS BCP-47 standard pour l'Ewe.
Le `TtsService` expose un point d'extension prêt à brancher :

```dart
// lib/services/tts_service/tts_service.dart
if (locale == null) {
  // TODO: appel HTTP vers moteur TTS Ewe custom (ex. Coqui TTS, ElevenLabs)
  return;
}
```

Pour intégrer un moteur custom, remplacer ce bloc par un appel HTTP
sans modifier le reste de l'application.

---

## Stack technique

| Couche | Package | Version |
|--------|---------|---------|
| Inférence ML | `tflite_flutter` | 0.12.1 |
| Caméra | `camera` | 0.10.6 |
| État (MVVM) | `provider` | 6.1.5 |
| Animations | `flutter_animate` | 4.5.2 |
| Typographie | `google_fonts` | 6.3.3 |
| TTS | `flutter_tts` | 4.2.5 |
| HTTP | `http` | 1.6.0 |
| Persistance | `shared_preferences` | 2.5.5 |
| Chemins | `path_provider` | 2.1.5 |
| Permissions | `permission_handler` | 11.4.0 |

---

## Structure des assets

```
assets/
├── models/
│   ├── detect_en.tflite     ✅  SSD MobileNet V1 COCO — 4 MB
│   ├── detect_fr.tflite     ⏳  À entraîner
│   └── detect_ewe.tflite    ⏳  À entraîner
└── labels/
    ├── labels_en.txt        80 classes COCO — English
    ├── labels_fr.txt        80 classes COCO — Français (UTF-8)
    └── labels_ewe.txt       80 classes COCO — Èvègbe (UTF-8 + alphabet Ewe)
```

---

## Configuration Android critique

Deux blocs dans `android/app/build.gradle.kts` sont obligatoires pour TFLite :

```kotlin
// Empêche la compression des modèles dans l'APK
// TFLite mappe les fichiers en mémoire — un modèle compressé = crash au chargement
androidResources {
    noCompress += listOf("tflite", "lite")
}

// Résout les conflits de bibliothèques natives entre tflite_flutter et camera
packaging {
    jniLibs {
        pickFirsts += setOf(
            "lib/x86/libc++_shared.so",
            "lib/x86_64/libc++_shared.so",
            "lib/armeabi-v7a/libc++_shared.so",
            "lib/arm64-v8a/libc++_shared.so",
        )
    }
}
```

---

## Roadmap

- [ ] Modèle Français (`detect_fr.tflite`)
- [ ] Modèle Ewe (`detect_ewe.tflite`)
- [ ] Moteur TTS Ewe (Coqui TTS via HTTP local)
- [ ] Accélération GPU — TFLite GPU Delegate
- [ ] Mode entièrement hors-ligne (modèles bundlés dans l'APK)
- [ ] Support iOS (BGRA8888 déjà géré dans `image_utils.dart`)
- [ ] Export des détections JSON / CSV

---

## Licence

Usage personnel et éducatif.
SSD MobileNet V1 — Apache 2.0 © Google.
