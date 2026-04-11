# Debug Keystore — DEBUG-ONLY

This keystore is committed to the repo so CI can produce a "signed debug AAB" without secrets plumbing. It is **DEBUG-ONLY**. Never use it for a Play Store upload.

## Details

- **Path:** `android/keys/debug.keystore`
- **Alias:** `murmurdebug`
- **Password (store and key):** `murmurdebug`
- **DN:** `CN=Jake McLaughlin, O=Murmur, C=US`
- **Validity:** 10000 days
- **Algorithm:** RSA 2048

## Phase 7 Rotation

Before Phase 7 Play Store upload (requirement QAL-05), this keystore MUST be replaced with an upload keystore stored in GitHub Secrets. The `signingConfigs` block in `android/app/build.gradle.kts` will be updated to read `storePassword`, `keyAlias`, and `keyPassword` from environment variables injected by CI. Phase 7 plan should include a "keystore rotation" task.

## Warning

If Play Store ever sees a build signed with this debug keystore, the app identity is **permanently burned** — Google does not allow re-uploads with a different signing cert for the same package name. Double-check every Phase 7 CI job uses the rotated upload keystore before pushing.
