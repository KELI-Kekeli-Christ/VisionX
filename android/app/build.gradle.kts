plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.visionx.visionx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.visionx.visionx"
        // Camera2 + TFLite requièrent API 21 minimum
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Empêche la compression des modèles TFLite dans l'APK
    // (nécessaire pour que TFLite puisse mapper le fichier en mémoire)
    androidResources {
        noCompress += listOf("tflite", "lite")
    }

    // Résout les conflits de bibliothèques natives entre tflite_flutter
    // et les autres packages AAR (camera, etc.)
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
}

flutter {
    source = "../.."
}
