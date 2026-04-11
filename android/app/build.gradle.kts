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
        create("debugCommitted") {
            storeFile = file("../keys/debug.keystore")
            storePassword = "murmurdebug"
            keyAlias = "murmurdebug"
            keyPassword = "murmurdebug"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debugCommitted")
        }
        release {
            // Phase 1 uses the committed debug keystore for release too so CI can produce
            // a "signed debug AAB" with zero secrets plumbing. Phase 7 (QAL-05) replaces
            // this with an upload keystore from GitHub Secrets. See android/keys/README.md.
            signingConfig = signingConfigs.getByName("debugCommitted")
        }
    }
}

flutter {
    source = "../.."
}
