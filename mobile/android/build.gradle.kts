allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ffmpeg_kit_flutter_min 5.1.0 predates AGP 8 namespace requirement.
    // Inject namespace for affected modules so the build doesn't fail.
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                if (androidExt.namespace == null) {
                    val pkg = try {
                        val manifest = file("src/main/AndroidManifest.xml")
                        if (manifest.exists()) {
                            val xml = groovy.xml.XmlSlurper().parse(manifest)
                            xml.getProperty("@package")?.toString()
                        } else null
                    } catch (_: Exception) { null }
                    if (pkg != null && pkg.isNotEmpty()) {
                        androidExt.namespace = pkg
                    }
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
