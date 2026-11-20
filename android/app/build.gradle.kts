import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

/** A required entry of key.properties, with an error that names the missing key. */
fun releaseKeyProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("android/key.properties is missing '$name'.")

// A release build signed with the debug key cannot later be updated by the real release key,
// so it is only allowed when explicitly requested for local testing:
//   flutter build apk --release --android-project-arg=myvault.allowDebugSigning=true
// or with the environment variable MYVAULT_ALLOW_DEBUG_SIGNING=true.
val allowDebugReleaseSigning =
    (project.findProperty("myvault.allowDebugSigning") as String?)?.toBoolean() == true ||
        System.getenv("MYVAULT_ALLOW_DEBUG_SIGNING")?.toBoolean() == true

android {
    namespace = "com.personalvault.myvault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.personalvault.myvault"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = releaseKeyProperty("keyAlias")
                keyPassword = releaseKeyProperty("keyPassword")
                storeFile = file(releaseKeyProperty("storeFile"))
                storePassword = releaseKeyProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                logger.warn(
                    "WARNING: signing this release build with the DEBUG key " +
                        "(myvault.allowDebugSigning). Do not distribute it.",
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

// Fail fast, before compiling, when a release build has no release key (instead of
// silently producing a debug-signed release). Debug builds are unaffected.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        task.project == project && task.name.contains("Release") &&
            listOf("assemble", "bundle", "package").any { task.name.startsWith(it) }
    }
    if (buildsRelease && !hasReleaseKeystore && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release builds need android/key.properties (keyAlias, keyPassword, storeFile, " +
                "storePassword). See https://docs.flutter.dev/deployment/android#sign-the-app. " +
                "For a local test build only, pass " +
                "--android-project-arg=myvault.allowDebugSigning=true.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // BiometricPrompt + CryptoObject for the Keystore-bound biometric key (BiometricKeyChannel.kt)
    implementation("androidx.biometric:biometric:1.1.0")
}
