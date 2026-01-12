pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }
    settings.ext.flutterSdkPath = flutterSdkPath()

    includeBuild("${settings.ext.flutterSdkPath}/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    // Используем стабильную версию 8.7.0 (она у вас уже есть и работает)
    id "com.android.application" version "8.7.0" apply false 
    // ОБНОВЛЕНИЕ: Поднимаем Kotlin до 2.0.20, чтобы убрать Warning
    id "org.jetbrains.kotlin.android" version "2.0.20" apply false 
}

include ":app"
