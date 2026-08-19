# Gradle Wrapper validation — KOMBAX RC13 build 20037

## Implemented

- `android/gradlew`
- `android/gradlew.bat`
- `android/gradle/wrapper/gradle-wrapper.jar`
- `android/gradle/wrapper/gradle-wrapper.properties`

## Pinned toolchain

- Android Gradle Plugin: `8.10.1` (existing project configuration)
- Gradle Wrapper distribution: `8.11.1`
- Gradle distribution: `gradle-8.11.1-bin.zip`
- Distribution SHA-256: `f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6`
- Wrapper JAR SHA-256: `2db75c40782f5e8ba1fc278a5574bab070adccb2d21ca5a6e5ed840888448046`

## Validation performed

- Wrapper JAR checksum matches the official Gradle 8.11.1 wrapper checksum.
- Wrapper JAR ZIP structure validated with no errors.
- POSIX launcher syntax validated with `sh -n`.
- Existing KOMBAX automated test suite executed successfully, including `KOMBAX 20037 RELEASE HARDENING: PASS`.
- Android version remains unchanged: `versionCode 20037`, `versionName 2.0.0-rc.13`.
- Android SDK configuration remains unchanged: `compileSdk 36`, `targetSdk 36`, `minSdk 24`.

## Local build commands

Windows CMD / PowerShell:

```bat
cd android
gradlew.bat --version
gradlew.bat assembleDebug
gradlew.bat bundleRelease
```

macOS / Linux:

```sh
cd android
./gradlew --version
./gradlew assembleDebug
./gradlew bundleRelease
```

The first invocation downloads the pinned Gradle 8.11.1 distribution and verifies its SHA-256 before use. Release signing still depends on the existing KOMBAX/Urban Warriors keystore configuration; Firebase production configuration depends on the real `google-services.json`.
