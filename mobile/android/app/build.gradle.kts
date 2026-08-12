plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.qrflow.app"
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
        applicationId = "com.qrflow.app"
        // API 26 minimum : TYPE_APPLICATION_OVERLAY (bulle + fenêtre de
        // résultat) et icône adaptative ne sont disponibles qu'à partir de là.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // À remplacer par un vrai keystore avant publication Play Store.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Décodage ML Kit natif pour la capture d'écran (bulle).
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}
