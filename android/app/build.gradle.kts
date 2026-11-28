plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val parallelInstall = providers.gradleProperty("parallelInstall").orNull == "true"

android {
    namespace = "com.example.furry_content_hub"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = if (parallelInstall) {
            "com.example.furry_content_hub.preview.v${flutter.versionCode}"
        } else {
            "com.example.furry_content_hub"
        }
        manifestPlaceholders["hubAppLabel"] = if (parallelInstall) "Furry Hub (тест)" else "Furry Hub"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
