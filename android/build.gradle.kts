// Add repositories inside the buildscript block
buildscript {
    repositories {
        google() // Google Maven Repository
        mavenCentral() // Central Repository for dependencies
        gradlePluginPortal() // Additional Gradle plugins
    }

    dependencies {

        classpath("com.android.tools.build:gradle:8.8.0")
        classpath("com.google.gms:google-services:4.4.2") // Firebase Google Service
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")

    }
} // <-- Closing bracket added here

allprojects {
    repositories {
        google() // Google Maven Repository
        mavenCentral() // Central Repository
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

