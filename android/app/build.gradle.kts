import java.util.Properties
import java.io.FileInputStream
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseKeyAlias: String? = keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword: String? = keystoreProperties.getProperty("keyPassword")
val releaseStoreFile: String? = keystoreProperties.getProperty("storeFile")
val releaseStorePassword: String? = keystoreProperties.getProperty("storePassword")
val hasReleaseSigning: Boolean =
    !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank() &&
        !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank()
android {
    namespace = "com.secondchat.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.secondchat.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword!!
            }
        }
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
//            signingConfig = signingConfigs.getByName("debug")
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            
            // ProGuard rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // Split APKs by ABI to reduce individual APK size
    // Uncomment below to enable split APKs (use with --split-per-abi flag)
    // splits {
    //     abi {
    //         isEnable = true
    //         reset()
    //         include("armeabi-v7a", "arm64-v8a", "x86_64")
    //         isUniversalApk = false
    //     }
    // }
}

flutter {
    source = "../.."
}
