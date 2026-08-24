import java.util.Properties

// مفتاح الإصدار — اختياري.
//
// إن وُجد `android/key.properties` وُقّع التطبيق بمفتاح صاحب المحل، وإلا
// عاد إلى مفتاح debug ليبقى البناء ممكناً على أي جهاز بلا إعداد.
//
// ⚠️ الملف والمفتاح **لا يُرفعان إلى Git** (مستثنيان في .gitignore).
// فقدان المفتاح يعني أن أي تحديث لاحق سيرفضه أندرويد على الأجهزة
// المثبَّت عليها التطبيق، فيضطر المستخدم للحذف وفقدان إعداداته —
// احتفظ بنسخة منه في مكان آمن.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // يجب أن يأتي بعد Android و Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.kmsan.kmsan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ⚠️ يجب أن يساوي package_name في google-services.json حرفياً وبالأحرف
        // الكبيرة، وإلا رفض plugin غوغل الربط وفشلت الترجمة.
        applicationId = "KMSAN.APP"
        // firebase_auth يتطلب minSdk 23 على الأقل.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // مفتاح الإصدار إن وُجد، وإلا debug حتى لا ينكسر البناء.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // ماسح غوغل الرسمي — الواجهة ذات الزوايا الملوّنة وسطر "Scanned by Google".
    // لا يطلب صلاحية كاميرا لأن المسح يجري في عملية خدمات غوغل نفسها.
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
