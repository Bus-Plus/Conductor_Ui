plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase config
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter must be last
}

android {
    namespace = "com.example.bus_tracking_conductor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // 🔧 Required by Firebase

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.bus_tracking_conductor"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

apply(plugin = "com.google.gms.google-services")
