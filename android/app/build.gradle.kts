plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lunya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Обновлено до Java 17 (стандарт для новых Gradle)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.lunya"
        // Явно ставим 21, чтобы избежать конфликтов с url_launcher/async_wallpaper
        minSdk = 21 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Отключаем сжатие, чтобы избежать ошибок R8/Proguard
            isMinifyEnabled = false
            isShrinkResources = false
            
            // Используем debug ключ для быстрой проверки релиза
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
