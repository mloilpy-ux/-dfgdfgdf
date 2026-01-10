allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ИСПРАВЛЕННАЯ ЧАСТЬ НИЖЕ
subprojects {
    afterEvaluate {
        // Ищем Android-расширение безопасным способом
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // Используем рефлексию (reflection), чтобы установить namespace
                // без необходимости подключать сложные импорты
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)

                val currentNamespace = getNamespace.invoke(android)
                
                // Если namespace пустой, устанавливаем его принудительно
                if (currentNamespace == null) {
                    val groupString = if (group.toString().isEmpty() || group.toString() == "null") "com.example.plugin.${name}" else group.toString()
                    setNamespace.invoke(android, groupString)
                }
            } catch (e: Exception) {
                // Игнорируем ошибки, если структура плагина отличается
            }
        }
    }
}
