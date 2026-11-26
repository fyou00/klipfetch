import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) {
    FileInputStream(keyPropertiesFile).use { keyProperties.load(it) }
}

fun signingValue(propKey: String, envKey: String): String? {
    val prop = keyProperties.getProperty(propKey)?.trim()
    if (!prop.isNullOrEmpty()) return prop
    val env = System.getenv(envKey)?.trim()
    return env?.takeIf { it.isNotEmpty() }
}

val releaseStoreFilePath = signingValue("storeFile", "KLIPFETCH_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "KLIPFETCH_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "KLIPFETCH_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "KLIPFETCH_KEY_PASSWORD")
val releaseStoreFile = releaseStoreFilePath?.let { path ->
    val candidate = File(path)
    if (candidate.isAbsolute) candidate else rootProject.file(path)
}
val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStoreFile.isFile &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

android {
    namespace = "io.github.fyou00.klipfetch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.fyou00.klipfetch"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val isSplitPerAbi =
            project.findProperty("split-per-abi")?.toString()?.toBoolean() == true
        if (!isSplitPerAbi) {
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
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
    val youtubedlAndroidVersion = "0.18.1"
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("io.github.junkfood02.youtubedl-android:library:$youtubedlAndroidVersion")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$youtubedlAndroidVersion")
    implementation("io.github.junkfood02.youtubedl-android:aria2c:$youtubedlAndroidVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
