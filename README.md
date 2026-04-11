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

# Install the pinned toolchain
mise install

# Accept Android SDK licenses + install components
mise run setup-android

# Verify
mise exec -- flutter doctor
```

## Physical Device Install (Android)

This section is completed by Plan 09.

## Project Structure

This section is completed by Plan 08.
