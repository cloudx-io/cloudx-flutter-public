plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.cloudx.cloudx_flutter_public_demo"
    /*
     * io.cloudx:adapter-meta needs API 36, because Meta Audience Network
     * 6.22.0 depends on androidx.browser 1.9.0. Flutter 3.47 already supplies
     * 36; maxOf keeps tracking Flutter upward on newer versions while holding
     * the floor on the older ones this demo still invites. targetSdk is
     * unaffected.
     */
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        /*
         * Bid requests are authorized per app key AND application id, so this
         * has to name the CloudX dashboard app the key in
         * lib/cloudx/demo_config.dart belongs to. Replace both together.
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
     * declared here as well so the version is visible in one place.
     *
     * Every CloudX dependency is declared by major version and resolves to the
     * newest release on that line, so the demo does not go stale between
     * releases. Gradle has no optimistic operator; "4.+" is its equivalent of
     * the Podfile's "~> 4.0".
     */
    implementation("io.cloudx:sdk:4.+")

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
    /*
     * BIGO is in this file but not in the Podfile, which is why the Podfile
     * lists one network fewer. An iOS adapter does exist, but with that pod
     * installed the Flutter tool drops arm64 from Simulator builds, and the
     * resulting x86_64-only Runner will not install on an Apple Silicon
     * simulator. Test BIGO on a physical iOS device.
     *
     * On Android it needs the cleartext rule in
     * res/xml/network_security_config.xml, referenced from the manifest - the
     * adapter does not add that itself.
     */
    implementation("io.cloudx:adapter-bigo:6.+")
    implementation("io.cloudx:adapter-meta:6.+")
    implementation("io.cloudx:adapter-vungle:7.+")
    implementation("io.cloudx:adapter-inmobi:11.+")
    implementation("io.cloudx:adapter-mintegral:17.+")
    implementation("io.cloudx:adapter-unityads:4.+")
    implementation("io.cloudx:adapter-magnite:1.+")
    implementation("io.cloudx:adapter-moloco:4.+")
    implementation("io.cloudx:adapter-verve:3.+")
    implementation("io.cloudx:adapter-digitalturbine:8.+")
    implementation("io.cloudx:adapter-pangle:8.+")
    implementation("io.cloudx:adapter-mobilefuse:1.+")
    implementation("io.cloudx:adapter-taurusx:1.+")
}
