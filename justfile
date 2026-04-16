set shell := ["mise", "exec", "--", "bash", "-uc"]

# Recipes run through `mise exec --` so the Flutter/Dart/Android toolchain
# pinned in .mise.toml is on PATH — no shell activation required.

default:
    @just --list

# Verify the pinned Flutter + Android toolchain
doctor:
    flutter doctor

# Fetch Dart dependencies
get:
    flutter pub get

# One-shot code generation (riverpod + drift)
gen:
    dart run build_runner build --delete-conflicting-outputs

# Watch-mode code generation
watch:
    dart run build_runner watch --delete-conflicting-outputs

# Run on the first connected device (hot reload)
run *args:
    flutter run {{args}}

# Run tests
test *args:
    flutter test {{args}}

# Static analysis
analyze:
    flutter analyze

# Format all Dart sources
fmt:
    dart format lib test

# List connected devices + emulators
devices:
    flutter devices

# Build a signed debug AAB (debug keystore — see android/keys/README.md)
build-aab:
    flutter build appbundle --debug

# Clean build artefacts
clean:
    flutter clean
