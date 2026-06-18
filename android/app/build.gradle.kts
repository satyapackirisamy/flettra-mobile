import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Load local.properties (MAPS_API_KEY, etc.) ────────────────────────────────
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val mapsApiKey: String = localProps.getProperty("MAPS_API_KEY") ?: ""

// ── Load signing keystore (android/key.properties) ────────────────────────────
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.flettra.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProps.getProperty("keyAlias")     ?: "flettra"
            keyPassword  = keyProps.getProperty("keyPassword")  ?: ""
            storeFile    = file(keyProps.getProperty("storeFile") ?: "flettra-release.jks")
            storePassword = keyProps.getProperty("storePassword") ?: ""
        }
    }

    defaultConfig {
        applicationId  = "com.flettra.app"
        minSdk         = 21          // covers ~99% of active Android devices
        targetSdk      = flutter.targetSdkVersion
        versionCode    = 1
        versionName    = "1.0.0"
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig   = signingConfigs.getByName("release")
            isMinifyEnabled = false   // set true + add proguard rules when ready
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
