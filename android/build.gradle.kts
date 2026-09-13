allprojects {
    repositories {
        google()
        mavenCentral()
        // Each of these serves exactly one network SDK that is not on Maven Central.
        maven {
            url = uri("https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea")
        }
        maven {
            url = uri("https://verve.jfrog.io/artifactory/verve-gradle-release")
        }
        maven {
            url = uri("https://artifact.bytedance.com/repository/pangle")
        }
        maven {
            url = uri("https://artifact.taurusx.com/artifactory/taurusx-sdk/")
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
