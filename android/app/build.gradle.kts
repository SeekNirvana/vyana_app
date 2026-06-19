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
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun Properties.signingReady(prefix: String): Boolean {
    val password = getProperty("${prefix}StorePassword")?.trim().orEmpty()
    val alias = getProperty("${prefix}KeyAlias")?.trim().orEmpty()
    val storeFile = getProperty("${prefix}StoreFile")?.trim().orEmpty()
    return password.isNotEmpty() &&
        !password.startsWith("PASTE_") &&
        alias.isNotEmpty() &&
        storeFile.isNotEmpty()
}

android {
    namespace = "com.seeknirvana.vyana"
    // flutter_gemma (MediaPipe GenAI) needs compileSdk 35+ and a recent NDK.
    // Pinned to the versions the SeekNirvana app builds against.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.seeknirvana.vyana"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // On-device AI (flutter_gemma / whisper.cpp) is 64-bit only — multi-GB
        // models can't run on 32-bit, and whisper.cpp fails to compile for the
        // legacy x86 ABI. Ship arm64 (devices) + x86_64 (emulators) only.
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (keystoreProperties.signingReady("googlePlay")) {
            create("releaseGooglePlay") {
                keyAlias = keystoreProperties.getProperty("googlePlayKeyAlias")
                keyPassword = keystoreProperties.getProperty("googlePlayKeyPassword")
                storeFile = file(keystoreProperties.getProperty("googlePlayStoreFile"))
                storePassword = keystoreProperties.getProperty("googlePlayStorePassword")
            }
        }
        if (keystoreProperties.signingReady("dappStore")) {
            create("releaseDappStore") {
                keyAlias = keystoreProperties.getProperty("dappStoreKeyAlias")
                keyPassword = keystoreProperties.getProperty("dappStoreKeyPassword")
                storeFile = file(keystoreProperties.getProperty("dappStoreStoreFile"))
                storePassword = keystoreProperties.getProperty("dappStoreStorePassword")
            }
        }
    }

    flavorDimensions += "store"
    productFlavors {
        create("googlePlay") {
            dimension = "store"
        }
        create("dappStore") {
            dimension = "store"
        }
    }

    buildTypes {
        release {
            // ProGuard/R8 files are applied by the Flutter Gradle plugin when
            // `shrink=true` in gradle.properties. Vyana sets shrink=false because
            // JNI plugins crash on launch when minified.
        }
    }
}

androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        val flavor = variant.flavorName ?: return@onVariants
        val signingName = when (flavor) {
            "dappStore" -> "releaseDappStore"
            "googlePlay" -> "releaseGooglePlay"
            else -> return@onVariants
        }
        val config = android.signingConfigs.findByName(signingName) ?: return@onVariants
        variant.signingConfig.setConfig(config)
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
    implementation("com.solanamobile:mobile-wallet-adapter-clientlib:1.1.0")
}