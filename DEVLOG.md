# ConvertX Android — Development Log

**Repo:** https://github.com/agni-007/ConvertX-Android  
**Stack:** Flutter 3.x stable · Dart 3 · Material 3  
**Last updated:** 2026-06-09  
**Current status:** CI build in progress after latest fix (commit `4afedd3`)

---

## Project Overview

ConvertX Android is a fully offline universal file converter for Android 8.0+.  
It is a **completely separate repo and codebase** from the Windows app (`agni-007/ConvertX`).

- Pure Dart converters for images, PDF, documents
- SQLite via `sqflite` for history and presets
- Minimum SDK: 26 (Android 8.0)
- Target: split APKs per ABI ≤ 20 MB each

---

## Version Chain (Critical — must stay in sync)

| Component | Current version | Minimum required by |
|---|---|---|
| Flutter | 3.x stable (CI) | — |
| Gradle | 8.14.1 | Flutter 3.44 |
| AGP (Android Gradle Plugin) | 8.11.1 | Gradle 8.14.1 |
| Kotlin (KGP) | 2.2.20 | Flutter 3.44 check |
| Java | 17 | AGP 8.x |
| Dart SDK | ^3.11.5 | pubspec.yaml |

**Rule:** When Flutter is upgraded, check the new minimum Gradle/AGP/Kotlin versions first.  
Flutter CI prints warnings with exact version numbers needed — those are the source of truth.

---

## Build Errors Encountered & Fixes

### Error 1 — `flutter analyze --fatal-infos` failures
**Commit:** `b8b8995`  
**Symptom:** 5 lint issues caused CI to fail at the analyze step.  
**Cause:** `DropdownButtonFormField` used `value:` instead of `initialValue:`, missing `const` on widgets.  
**Fix:** Changed `value:` → `initialValue:` on all form fields; added `const` to static widgets.  
**Avoid:** Run `flutter analyze` locally before every push.

---

### Error 2 — `ffmpeg_kit_flutter_min` Maven artifact missing
**Commits:** `d1e89be`, `0196c0e`  
**Symptom:**
```
Could not find com.arthenica:ffmpeg-kit-min:5.1
Searched: google(), mavenCentral(), flutter.io
```
**Cause:** `ffmpeg_kit_flutter_min` is an abandoned package. Its Maven artifacts were never
published reliably. Version 5.1.0 maps to Maven coordinate `ffmpeg-kit-min:5.1` which
does not exist on any public repo. Version 6.x artifacts are also missing.  
**Fix:** Removed `ffmpeg_kit_flutter_min` from `pubspec.yaml` entirely.  
`MediaConverter` now throws `UnsupportedError` — video/audio conversion is deferred to v2.  
**Avoid:** Do not re-add `ffmpeg_kit_flutter_min` or `ffmpeg_kit_flutter` from pub.dev.
If video/audio conversion is needed in future, bundle a static FFmpeg binary via
a platform channel or use `ffmpeg_kit_flutter` from a git source with prebuilt AARs.

---

### Error 3 — AGP namespace error (ffmpeg_kit + AGP 8)
**Commit:** `38df503`  
**Symptom:**
```
Namespace not specified. Specify a namespace in the module's build.gradle
```
**Cause:** AGP 8 requires every library module to declare a `namespace`. `ffmpeg_kit_flutter_min`
5.1.0 predates this requirement.  
**Fix (at the time):** Added `afterEvaluate` block in root `build.gradle.kts` to inject namespace
from `AndroidManifest.xml` `package` attribute.  
**Current state:** No longer relevant — ffmpeg_kit removed entirely.

---

### Error 4 — Kotlin language version 1.4 / version chain mismatch
**Commit:** `38df503`  
**Symptom:**
```
Kotlin language version 1.4 is deprecated and its support will be removed in a future version
```
**Cause:** AGP 7.4.2 with Kotlin 1.8.22 triggered old language level defaults.  
**Fix:** Upgraded to AGP 8.3.2, Kotlin 1.9.25, Gradle 8.4.

---

### Error 5 — Gradle too old (multiple rounds)
**Commits:** `dfc250f`, `5df0c0d`, `121f9f3`, `306913c`  
**Symptom (repeated pattern):**
```
Minimum supported Gradle version is X.Y. Current version is A.B.
```
**Cause:** Each AGP upgrade raises the minimum Gradle version. Flutter 3.44 also added
its own floor checks.  
**Progression:**
- Gradle 7.6.1 → needed 7.6.3
- Gradle 8.4 → needed 8.7 (Flutter check)
- Gradle 8.7 → needed 8.9 (AGP 8.7.0)
- Gradle 8.9 → needed 8.11.1 (AGP 8.9.0)
- Gradle 8.11.1 → needed 8.14.1 (Flutter 3.44 deprecation warning)

**Fix:** Bump `gradle-wrapper.properties` distributionUrl to the required version.  
**Avoid:** Always upgrade Gradle AND AGP together using the compatibility table:  
https://developer.android.com/build/releases/gradle-plugin#updating-gradle

---

### Error 6 — R8 missing Play Core classes
**Commit:** `4afedd3`  
**Symptom:**
```
ERROR: R8: Missing class com.google.android.play.core.splitcompat.SplitCompatApplication
Missing class com.google.android.play.core.splitinstall.*
```
**Cause:** R8 minification (`isMinifyEnabled = true`) ran against Flutter's engine which
references Play Core for deferred/dynamic delivery. Play Core wasn't in the dependency
tree so R8 failed.  
**Fix:**  
1. Added `implementation("com.google.android.play:core:1.10.3")` to `app/build.gradle.kts`  
2. Added to `proguard-rules.pro`:
   ```
   -keep class com.google.android.play.core.** { *; }
   -dontwarn com.google.android.play.core.**
   ```
**Avoid:** Any time R8 is enabled (`isMinifyEnabled = true`), Flutter's engine deps must
be in the dependency tree. If Flutter is upgraded and new "missing class" errors appear,
check `missing_rules.txt` in the build output and add those packages.

---

### Error 7 — Kotlin plugin warning (KGP 2.0.0 < required 2.2.20)
**Commit:** `4afedd3`  
**Symptom:**
```
Warning: Flutter support for your project's Kotlin version (2.0.0) will soon be dropped.
Please upgrade to at least 2.2.20
```
**Cause:** After removing the explicit `kotlin-android` plugin declaration from
`settings.gradle.kts`, Flutter's bundled Kotlin 2.0.0 was used instead.  
**Fix:** Re-added `id("org.jetbrains.kotlin.android") version "2.2.20" apply false`
to `settings.gradle.kts`.  
**Avoid:** Always keep an explicit Kotlin version in `settings.gradle.kts`. Do not rely
on Flutter's bundled version — it lags behind.

---

## Current File State

### `mobile/android/gradle/wrapper/gradle-wrapper.properties`
```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14.1-all.zip
```

### `mobile/android/settings.gradle.kts` (key lines)
```kotlin
id("com.android.application") version "8.11.1" apply false
id("org.jetbrains.kotlin.android") version "2.2.20" apply false
```

### `mobile/android/app/build.gradle.kts` (key sections)
```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "dev.convertx.convertx"
    compileSdk = flutter.compileSdkVersion
    minSdk = 26
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
dependencies {
    implementation("com.google.android.play:core:1.10.3")
}
```

### `mobile/pubspec.yaml` (key deps)
```yaml
image: ^4.1.7
pdf: ^3.10.8
printing: ^5.12.0
excel: ^4.0.6
file_picker: ^8.0.0+1
path_provider: ^2.1.2
sqflite: ^2.3.3+1
permission_handler: ^11.3.1
path: ^1.9.0
uuid: ^4.4.0
open_filex: ^4.3.4
```
Note: `ffmpeg_kit_flutter_min` intentionally absent — see Error 2 above.

---

## What's Not Done Yet (v2 scope)

- Video/audio conversion (blocked on ffmpeg — see Error 2)
- Release signing (currently uses debug keystore)
- Play Store listing / upload
- App icon (uses Flutter default)
- Localization / i18n

---

## Resuming on a New Machine

```bash
git clone https://github.com/agni-007/ConvertX-Android.git
cd ConvertX-Android/mobile
flutter pub get
flutter analyze
flutter build apk --release --split-per-abi
```

Prerequisites: Flutter stable, Java 17, Android SDK with platform 31+.  
Set git identity before committing:
```bash
git config user.name "agni-007"
git config user.email "181618466+agni-007@users.noreply.github.com"
```
