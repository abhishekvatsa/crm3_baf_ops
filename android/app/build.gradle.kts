plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.crm3_baf_ops"

    // Explicitly set to 36 for 2026 dependency compatibility
    compileSdk = 36

    ndkVersion = "28.2.13676358"

    compileOptions {
        // AGP 8.9.1+ requires Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.crm3_baf_ops"

        // Overriding targetSdk to 36 for androidx.core:1.18.0
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // In KTS, assignment requires '='
            signingConfig = signingConfigs.getByName("debug")

            // Fixes your 'Unresolved reference' errors
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}