plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.convertx.convertx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.convertx.app"
        minSdk = 26  // Android 8.0 — SRS §2.3.2
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // R8 shrinking — SRS §7.5 (keeps APK ≤ 20 MB)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }


}

dependencies {
    // Play Core stubs — required by Flutter's deferred component engine at R8 time
    implementation("com.google.android.play:core:1.10.3")
}

flutter {
    source = "../.."
}
