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

// The Agora plugin still declares compileSdk 31, but the AndroidX libraries it pulls in need 34+,
// which makes the build stop at "checkDebugAarMetadata". Raise the plugins' compileSdk here.
// This only changes which Android APIs the plugin is compiled against, not how it behaves.
// It must come before evaluationDependsOn below, because afterEvaluate cannot be added to a project
// that has already been evaluated.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder {
                "compileSdkVersion"(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
