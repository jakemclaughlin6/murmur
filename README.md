# murmur

Offline EPUB reader with on-device neural TTS. Paid one-time purchase. No accounts, no cloud, no telemetry.

## Bootstrap (first-time setup)

murmur uses [mise](https://mise.jdx.dev/) to pin its toolchain. Nothing is installed to the host system.

```sh
# Install mise (one time)
curl https://mise.run | sh

# Install mise plugins (one time)
mise plugin install flutter https://github.com/mise-plugins/mise-flutter.git
mise plugin install android-sdk https://github.com/mise-plugins/mise-android-sdk.git

# Install the pinned toolchain (Flutter 3.41.0, Java 17, android-sdk)
mise install

# Accept Android SDK licenses + install platform-tools + build-tools + platforms;android-34
mise run setup-android

# Verify toolchain is green
mise exec -- flutter doctor
```

## Running locally

```sh
# Resolve dependencies
mise exec -- flutter pub get

# Run generated code (riverpod + drift)
mise exec -- dart run build_runner build --delete-conflicting-outputs

# Run on a connected Android device
mise exec -- flutter run

# Run tests
mise exec -- flutter test

# Build a signed debug AAB (uses committed debug keystore — DEBUG ONLY, rotated in Phase 7)
mise exec -- flutter build appbundle --debug
```

## Physical Device Install (Android)

The signed debug AAB produced by `flutter build appbundle --debug` is NOT directly installable via `adb install` — AAB files require conversion to APK first. Use Google's `bundletool`:

```sh
# Download bundletool (one time)
curl -L https://github.com/google/bundletool/releases/latest/download/bundletool-all.jar -o bundletool.jar

# Build a universal APK from the signed debug AAB
java -jar bundletool.jar build-apks \
  --bundle=build/app/outputs/bundle/debug/app-debug.aab \
  --output=build/app/outputs/bundle/debug/app.apks \
  --mode=universal \
  --ks=android/keys/debug.keystore \
  --ks-pass=pass:murmurdebug \
  --ks-key-alias=murmurdebug \
  --key-pass=pass:murmurdebug

# Install on a connected device
java -jar bundletool.jar install-apks \
  --apks=build/app/outputs/bundle/debug/app.apks
```

**Simpler path for most dev loops:** use `mise exec -- flutter run --debug` — it installs via the APK pipeline directly and skips the AAB→APK conversion.

The CI-produced `murmur-debug.aab` artifact from GitHub Actions (see [CI section](#continuous-integration)) uses the same committed debug keystore, so it installs with the same bundletool commands above.

## iOS (Phase 1 status)

Phase 1 does **not** produce an installable iOS build. Per the [Phase 1 CONTEXT decisions D-05/D-06](.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md), Apple Developer Program enrollment is deferred to Phase 4. The Phase 1 iOS deliverable is an unsigned `.xcarchive` produced by the `ios-scaffold` GitHub Actions job, triggered manually via `workflow_dispatch`. The unsigned archive is not installable on a physical iPhone — it only proves that the Info.plist keys, bundle identifier, and iOS 17.0 deployment target compile on `macos-14`.

Full iOS signing, TestFlight uploads, and physical-device installs land in Phase 4 once the Apple Developer Program decision is made.

## Continuous Integration

GitHub Actions workflow: `.github/workflows/ci.yml`

- **`android` job:** runs on every push to main and every PR. Uses `ubuntu-latest`, installs Flutter 3.41.0 via `subosito/flutter-action@v2`, runs analyze + test, builds a signed debug AAB, uploads `murmur-debug.aab` as a workflow artifact (14-day retention).
- **`ios-scaffold` job:** runs ONLY on manual `workflow_dispatch` trigger (not on push or PR). Uses `macos-14`, runs `flutter build ios --no-codesign` and `xcodebuild archive` with `CODE_SIGN_IDENTITY=""`, uploads `murmur-unsigned.xcarchive` as a workflow artifact.

## Project Structure

```
murmur/
├── .github/workflows/ci.yml        # Android (push) + iOS scaffold (workflow_dispatch)
├── .mise.toml                      # Flutter 3.41.0, Java 17, android-sdk
├── android/
│   ├── app/
│   │   ├── build.gradle.kts       # minSdk=24, targetSdk=34, signed debug
│   │   └── src/main/AndroidManifest.xml  # FOREGROUND_SERVICE_MEDIA_PLAYBACK + POST_NOTIFICATIONS
│   └── keys/
│       ├── debug.keystore         # committed — DEBUG ONLY, rotated in Phase 7
│       └── README.md              # debug keystore warning + Phase 7 rotation note
├── ios/
│   ├── Runner/Info.plist          # FND-07 compliance keys (background audio, EPUB UTI, export compliance)
│   ├── Runner.xcodeproj/project.pbxproj  # IPHONEOS_DEPLOYMENT_TARGET = 17.0
│   └── Podfile                    # platform :ios, '17.0' + post_install safety net
├── lib/
│   ├── main.dart                  # triple-catch + ProviderScope + CrashLogger.initialize
│   ├── app/
│   │   ├── app.dart               # MurmurApp — MaterialApp.router consuming theme provider
│   │   └── router.dart            # go_router StatefulShellRoute.indexedStack, 3 branches
│   ├── core/
│   │   ├── crash/                 # JSONL crash logger + 1MB rotation + triple-catch
│   │   ├── db/                    # Drift v1, schemaVersion=1, zero tables
│   │   └── theme/                 # 4 ThemeData builders (Clay neutrals), theme mode provider
│   └── features/
│       ├── library/               # empty-state placeholder + Import CTA (no-op)
│       ├── reader/                # single RichText paragraph in Literata
│       └── settings/              # theme picker + font preview + crash log status
├── assets/fonts/
│   ├── literata/                  # Literata Regular + Bold (OFL)
│   ├── merriweather/              # Merriweather Regular + Bold (OFL)
│   └── OFL.txt
├── drift_schemas/
│   └── drift_schema_v1.json       # Phase 2 migration baseline
├── scripts/
│   ├── verify_android_manifest.sh # CI build gate
│   └── verify_ios_plist.sh        # CI build gate
├── test/
│   ├── crash/                     # CrashLogger unit tests
│   ├── db/                        # AppDatabase unit tests
│   ├── fonts/                     # font_bundle_test
│   ├── theme/                     # 4 themes + persistence tests
│   └── widget/                    # navigation + provider scope widget tests
└── pubspec.yaml
```

## Privacy

murmur makes exactly one network call in its entire lifetime: the one-time Kokoro TTS model download on first launch (Phase 4, not yet implemented). After that, airplane mode is a supported operating state. There are no accounts, no telemetry, no analytics, no crash reporting over the network. Crash logs are written to a local file at `${appDocumentsDir}/crashes/crashes.log` and never leave the device.

## License

Application code: TBD (will be set in Phase 7 before store submission).

Bundled fonts (Literata, Merriweather): [SIL Open Font License 1.1](assets/fonts/OFL.txt).
