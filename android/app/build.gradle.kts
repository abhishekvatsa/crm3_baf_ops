import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStoreFilePath = System.getenv("CRM_ANDROID_RELEASE_STORE_FILE")
val releaseStorePassword = System.getenv("CRM_ANDROID_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("CRM_ANDROID_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("CRM_ANDROID_RELEASE_KEY_PASSWORD")
val releaseTaskRequested =
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
val ciPackageProofRaw = System.getenv("CRM3_CI_PACKAGE_PROOF")
if (ciPackageProofRaw != null && ciPackageProofRaw != "true") {
    throw org.gradle.api.GradleException(
        "CRM3_CI_PACKAGE_PROOF must be absent or exactly true."
    )
}
val ciPackageProof = ciPackageProofRaw == "true"

// Opt-in development identity. Only tool/dev/run_dev.ps1 sets this, so ordinary
// debug builds - including the CI app-shell integration job and the CodeQL
// isolated Android compilation - keep the production application id and the
// Firebase configuration they already rely on.
val devAppRaw = System.getenv("CRM3_DEV_APP")
if (devAppRaw != null && devAppRaw != "true") {
    throw org.gradle.api.GradleException(
        "CRM3_DEV_APP must be absent or exactly true."
    )
}
val devApp = devAppRaw == "true"

val missingReleaseInputs = mapOf(
    "CRM_ANDROID_RELEASE_STORE_FILE" to releaseStoreFilePath,
    "CRM_ANDROID_RELEASE_STORE_PASSWORD" to releaseStorePassword,
    "CRM_ANDROID_RELEASE_KEY_ALIAS" to releaseKeyAlias,
    "CRM_ANDROID_RELEASE_KEY_PASSWORD" to releaseKeyPassword,
).filterValues { it.isNullOrBlank() }.keys

if (releaseTaskRequested && missingReleaseInputs.isNotEmpty()) {
    throw org.gradle.api.GradleException(
        "Release signing input missing: " + missingReleaseInputs.joinToString(", ")
    )
}
if (
    releaseTaskRequested &&
    !releaseStoreFilePath.isNullOrBlank() &&
    !file(releaseStoreFilePath).isFile
) {
    throw org.gradle.api.GradleException(
        "Release keystore file does not exist: " + releaseStoreFilePath
    )
}

android {
    namespace = "in.co.sail.bsl.crm3.bafops"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "in.co.sail.bsl.crm3.bafops"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["crm3FirebaseDataCollectionEnabled"] =
            (!ciPackageProof).toString()
        manifestPlaceholders["crm3FirebaseInitProviderEnabled"] =
            (!ciPackageProof).toString()
    }

    signingConfigs {
        create("production") {
            if (!releaseStoreFilePath.isNullOrBlank()) {
                storeFile = file(releaseStoreFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        // The development build installs alongside the production app under a
        // distinct application id, so a debug session can never overwrite or
        // require uninstalling the signed production app and its local records.
        //
        // This is deliberately a build-type suffix rather than a product
        // flavor. Introducing flavors would rename every assemble task
        // (assembleRelease becomes assembleProdRelease) and break the governed
        // production-artifact workflow, which invokes the unflavored tasks.
        // Release output, application id and signing are untouched here.
        getByName("debug") {
            if (devApp) {
                applicationIdSuffix = ".dev"
                versionNameSuffix = "-dev"
            }
            manifestPlaceholders["crm3AppLabel"] =
                if (devApp) "CRM-III BAF Ops DEV" else "CRM-III BAF Ops"
        }
        getByName("release") {
            manifestPlaceholders["crm3AppLabel"] = "CRM-III BAF Ops"
            signingConfig = signingConfigs.getByName("production")
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled = !ciPackageProof
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter { source = "../.." }
