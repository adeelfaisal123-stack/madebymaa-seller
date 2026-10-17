import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URI
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun projectProperty(name: String): String? =
    (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }

fun localProperty(name: String): String? =
    localProperties.getProperty(name)?.takeIf { it.isNotBlank() }

fun envProperty(name: String): String? {
    val value = System.getenv(name)
    return if (value.isNullOrBlank()) null else value
}

fun optica2AdminBaseUrl(): String {
    val configured =
        projectProperty("OPTICA2_API_URL")
            ?: localProperty("OPTICA2_API_URL")
            ?: envProperty("OPTICA2_API_URL")
    if (!configured.isNullOrBlank()) return configured.trim().trimEnd('/')

    val hostFile = rootProject.file("../lib/config/optica2_host.g.dart")
    if (hostFile.exists()) {
        val match = Regex("apiUrl\\s*=\\s*'([^']+)'").find(hostFile.readText())
        val fromDart = match?.groupValues?.getOrNull(1)
        if (!fromDart.isNullOrBlank()) return fromDart.trim().trimEnd('/')
    }

    return "https://madebymaa.online"
}

fun adminGoogleMapsApiKey(): String? {
    return try {
        val url = URI.create("${optica2AdminBaseUrl()}/api/seller/maps-config").toURL()
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 5000
            readTimeout = 5000
            setRequestProperty("Accept", "application/json")

            val sellerApiKey =
                projectProperty("OPTICA2_API_KEY")
                    ?: localProperty("OPTICA2_API_KEY")
                    ?: envProperty("OPTICA2_API_KEY")
            if (!sellerApiKey.isNullOrBlank()) {
                setRequestProperty("X-Seller-Api-Key", sellerApiKey)
            }
        }

        connection.inputStream.bufferedReader().use { reader ->
            val body = reader.readText()
            Regex("\"api_key\"\\s*:\\s*\"([^\"]+)\"")
                .find(body)
                ?.groupValues
                ?.getOrNull(1)
                ?.takeIf { it.isNotBlank() }
        }
    } catch (error: Exception) {
        logger.warn("Could not fetch Google Maps API key from Optica2 admin: ${error.message}")
        null
    }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.madebymaa.merchant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.madebymaa.merchant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        val mapsKey =
            adminGoogleMapsApiKey()
                ?: projectProperty("GOOGLE_MAPS_API_KEY")
                ?: localProperty("GOOGLE_MAPS_API_KEY")
                ?: envProperty("GOOGLE_MAPS_API_KEY")
                ?: ""
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsKey
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Release builds require android/key.properties with your Play upload keystore. " +
                        "Expected upload certificate SHA1: " +
                        "BB:CD:4C:08:CD:D1:A4:31:09:80:CD:7C:87:FC:9F:78:6E:B1:B3:29",
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
