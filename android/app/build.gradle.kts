import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// RELEASE SIGNING
// ---------------------------------------------------------------------------
// Signing details are read from android/key.properties, which is gitignored and
// which you create yourself — see README, "Signing you need to supply".
//
// If that file is absent (a fresh clone, or CI without secrets) the release
// build falls back to the debug key so `flutter build apk --release` still
// works for local testing. A debug-signed bundle CANNOT be uploaded to Google
// Play, so the build prints a warning when the fallback is used.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    logger.warn(
        "[kingdom_drop] android/key.properties not found — release builds will " +
        "be signed with the DEBUG key and cannot be uploaded to Google Play."
    )
}

android {
    namespace = "com.yourcompany.kingdomdrop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // CHANGE ME: must be globally unique on Google Play and must match
        // AppConfig.bundleId in lib/core/config/app_config.dart.
        applicationId = "com.yourcompany.kingdomdrop"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Driven by `version:` in pubspec.yaml. Bump the build number there for
        // every store upload.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Shrink and obfuscate. The Flutter engine's own rules are supplied
            // by the Gradle plugin; ours are in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // ---------------------------------------------------------------------
    // WorkManager — pinned to fix a release-only crash at process start.
    // ---------------------------------------------------------------------
    // Nothing in this app uses WorkManager directly. It arrives transitively:
    // play-services-ads (via google_mobile_ads) schedules its offline ad-ping
    // through a Worker, so androidx.work comes along with the ads SDK, and its
    // WorkManagerInitializer runs from androidx.startup's InitializationProvider
    // — a ContentProvider, so before Application.onCreate and long before
    // Flutter reaches runApp().
    //
    // WorkManager's WorkDatabase is a Room database, and Room instantiates the
    // generated WorkDatabase_Impl reflectively by name. R8 full mode (the
    // default since AGP 8, and this project is on AGP 9) strips or renames a
    // class nothing references statically, so the lookup fails and the
    // initializer throws:
    //
    //     Unable to get provider androidx.startup.InitializationProvider
    //     Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
    //
    // Release-only, because debug builds do not run R8 at all.
    //
    // The fix is a dependency one rather than a keep rule. Current Room ships
    // consumer ProGuard rules that keep exactly what it reflects into
    // (`-keep class * extends androidx.room.RoomDatabase { <init>(); }`); the
    // older Room that the ads SDK's older WorkManager pulls in does not, or
    // does so in a form R8 full mode no longer honours. Declaring a current
    // WorkManager here makes Gradle resolve it — highest version wins — and
    // brings the matching Room and its rules with it.
    //
    // Keep this until the ads SDK depends on a WorkManager new enough to make
    // it redundant. Verify with:
    //     ./gradlew :app:dependencies --configuration releaseRuntimeClasspath
    implementation("androidx.work:work-runtime:2.11.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
