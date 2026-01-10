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

// ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ДЛЯ ПЛАГИНОВ (NAMESPACE)
subprojects {
    val setupNamespace = { proj: Project ->
        val android = proj.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                
                if (getNamespace.invoke(android) == null) {
                    val groupString = if (proj.group.toString().isEmpty() || proj.group.toString() == "null") {
                        "com.example.plugin.${proj.name}"
                    } else {
                        proj.group.toString()
                    }
                    setNamespace.invoke(android, groupString)
                }
            } catch (e: Exception) {
                // Ошибка игнорируется, если проект не поддерживает установку namespace
            }
        }
    }

    // Ключевое исправление: проверяем, не завершена ли уже конфигурация проекта
    if (state.executed) {
        setupNamespace(this)
    } else {
        afterEvaluate {
            setupNamespace(this)
        }
    }
}
