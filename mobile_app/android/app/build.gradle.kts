/*
TapCall Android App Module Configuration

Purpose:
- Gradle build configuration for the TapCall Android application
- Defines compilation settings, dependencies, and build variants
- Integrates Flutter Gradle plugin for seamless Flutter-Android builds

Key Settings:
- Package name: com.tapcall.app
- Compile SDK: Inherited from Flutter (typically API 34+)
- Java/Kotlin target: Java 17 / JVM target 17
- Min SDK: Inherited from Flutter (typically API 21+)
- Version code/name: Inherited from Flutter (pubspec.yaml)

Build Types:
- Debug: Default signing, suitable for development and testing
- Release: Currently uses debug keys (TODO: add production signing config)

Flutter Integration:
- Flutter Gradle plugin handles Flutter code compilation and embedding
- Source path points to Flutter project root (../..)

Notes:
- Application ID must match package name in MainActivity.kt
- Accessibility service requires minSdk 21+ for gesture support
- Release builds should be signed with production keystore before distribution
*/

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tapcall.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tapcall.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
