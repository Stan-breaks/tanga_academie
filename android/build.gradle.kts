allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some Flutter plugins still hard-code a compileSdk lower than the one required
// by newer AndroidX artifacts (as of AGP 9 the AAR-metadata check is strict, so
// e.g. file_picker compiling against android-34 fails). Align every Android
// subproject to the app's compileSdk (36) so those checks pass. Reflection keeps
// this file independent of the AGP DSL classes.
subprojects {
    fun alignCompileSdkWithApp() {
        val android = extensions.findByName("android") ?: return
        val methods = android.javaClass.methods
        val setCompileSdk = methods.firstOrNull {
            it.name == "setCompileSdk" && it.parameterTypes.size == 1
        }
        if (setCompileSdk != null) {
            setCompileSdk.invoke(android, 36)
        } else {
            methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterTypes[0] == Integer.TYPE
            }?.invoke(android, 36)
        }
    }
    // Some subprojects (e.g. :app via evaluationDependsOn below) are already
    // evaluated by the time this runs, so guard against an illegal afterEvaluate.
    if (state.executed) {
        alignCompileSdkWithApp()
    } else {
        afterEvaluate { alignCompileSdkWithApp() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
