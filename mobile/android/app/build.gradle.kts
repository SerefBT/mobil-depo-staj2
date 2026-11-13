import java.util.Properties
plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("dev.flutter.flutter-gradle-plugin") }
val keyProperties = Properties()
val keyFile = rootProject.file("key.properties")
if (keyFile.exists()) keyFile.inputStream().use { keyProperties.load(it) }
android {
 namespace = "tr.mobildepo.mobil_depo"
 compileSdk = 36
 ndkVersion = flutter.ndkVersion
 compileOptions {
  isCoreLibraryDesugaringEnabled = true
  sourceCompatibility = JavaVersion.VERSION_17
  targetCompatibility = JavaVersion.VERSION_17
 }
 defaultConfig {
  applicationId = "tr.mobildepo.mobil_depo"
  minSdk = maxOf(24, flutter.minSdkVersion)
  targetSdk = 36
  versionCode = flutter.versionCode
  versionName = flutter.versionName
 }
 if (keyFile.exists()) {
  signingConfigs { create("release") {
   keyAlias = keyProperties.getProperty("keyAlias")
   keyPassword = keyProperties.getProperty("keyPassword")
   storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
   storePassword = keyProperties.getProperty("storePassword")
  } }
 }
 buildTypes { release { signingConfig = signingConfigs.getByName(if (keyFile.exists()) "release" else "debug") } }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }
