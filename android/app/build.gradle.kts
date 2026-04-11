plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.jmclaughlin.murmur"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "dev.jmclaughlin.murmur"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("debugForPhase1") {  // Phase 7 replaces with uploadKeystore from env vars.
            storeFile = file("../keys/debug.keystore")
            storePassword = "murmurdebug"
            keyAlias = "murmurdebug"
            keyPassword = "murmurdebug"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debugForPhase1")
        }
        release {
            // TODO(Phase 7 QAL-05): replace with uploadKeystore from env vars.
            // DANGER: uploading this to the Play Store permanently burns the app identity.
            signingConfig = signingConfigs.getByName("debugForPhase1")
        }
    }
}

flutter {
    source = "../.."
}
