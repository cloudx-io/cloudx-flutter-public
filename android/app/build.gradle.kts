plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.cloudx.cloudx_flutter_public_demo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        /*
         * Bid requests are authorized per app key AND application id, so this
         * has to name the CloudX dashboard app the key in
         * lib/config/demo_config.dart belongs to. Replace both together.
         */
        applicationId = "io.cloudx.sample"
        // io.cloudx:sdk requires 23; flutter.minSdkVersion is lower on older Flutter.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    /*
     * The cloudx_flutter plugin already brings io.cloudx:sdk transitively. It is
     * declared here as well so the version is visible and pinned in one place.
     */
    implementation("io.cloudx:sdk:4.7.0")

    /*
     * Adapters version independently of the SDK, on a
     * <network-sdk-version>.<adapter-revision> scheme. Take only the networks
     * your dashboard actually serves; every one of these adds to the APK.
     *
     * io.cloudx:adapter-googlewaterfall is deliberately absent. It runs AdMob
     * demand INSIDE the CloudX auction, which is the opposite of what this demo
     * shows: here AdMob is an external bid competing against CloudX through the
     * arbiter. Shipping both would make the two bids the same demand.
     */
    implementation("io.cloudx:adapter-meta:6.22.0.0")
    implementation("io.cloudx:adapter-vungle:7.7.7.0")
    implementation("io.cloudx:adapter-inmobi:11.4.0.1")
    implementation("io.cloudx:adapter-mintegral:17.1.71.1")
    implementation("io.cloudx:adapter-unityads:4.19.0.1")
    implementation("io.cloudx:adapter-magnite:1.0.0.1")
    implementation("io.cloudx:adapter-moloco:4.11.0.0")
    implementation("io.cloudx:adapter-verve:3.9.0.1")
    implementation("io.cloudx:adapter-digitalturbine:8.4.7.1")
    implementation("io.cloudx:adapter-pangle:8.2.0.4.0")
    implementation("io.cloudx:adapter-mobilefuse:1.12.0.0")
    implementation("io.cloudx:adapter-taurusx:1.18.3.0")
}
