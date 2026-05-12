plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.creddx.android"
    compileSdk = flutter.compileSdkVersion
    // NDK 28.2.13676358+ required for 16 KB page size support and jni plugin compatibility
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.creddx.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24  // Android 7.0+ for better security and features
        targetSdk = 35  // Android 15 for Play Store compliance
        versionCode = 33
        versionName = "3.4.6"

        // Play Store optimization
        multiDexEnabled = true

        // Support for 16 KB memory page sizes (Android 15+ requirement)
        ndk {
            abiFilters.add("armeabi-v7a")
            abiFilters.add("arm64-v8a")
            abiFilters.add("x86_64")
        }
    }

    signingConfigs {


        create("release") {
            storeFile = file("../coinCredProJks")
            storePassword = "123456"
            keyAlias = "coincred pro"
            keyPassword = "123456"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            isZipAlignEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isZipAlignEnabled = true
        }
    }

    // App Bundle configuration for 16KB page size support
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        // ML Kit libraries and others should be 16KB aligned
        // If some libraries still cause issues, they might need to be updated in pubspec.yaml
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Split Play Core libraries for SDK 34+ compatibility
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:review:2.0.2")
}


flutter {
    source = "../.."
}
