/*
TapCall Root Android Build Configuration

Purpose:
- Top-level Gradle build file for the Android project
- Configures repository sources for all subprojects (app module)
- Defines custom build directory structure (shared with Flutter)

Key Configuration:
- Repositories: Google Maven (Android libraries) and Maven Central (third-party)
- Build directory: Redirected to ../../build to consolidate Flutter and Android builds
- Clean task: Deletes the root build directory when running `./gradlew clean`

Notes:
- This is a Kotlin DSL file (.kts), not Groovy
- All subprojects inherit the repository and build directory settings
- The :app subproject (defined in settings.gradle.kts) depends on this configuration
*/

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()

subprojects {
    project.layout.buildDirectory.set(newBuildDir.dir(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
