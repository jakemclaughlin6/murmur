# Phase 4 Wave 0 — Device Verification Checklist

Run this on a physical Android device. iOS verification is deferred (no-Mac constraint).

## Prep
- [ ] Device: Android phone (mid-range or better), USB-debugging enabled
- [ ] `adb devices` shows the device
- [ ] On the device: Settings → Developer options → **Install via USB** enabled (Android 16+ adds this gate — required for `flutter install`)
- [ ] Download `kokoro-int8-en-v0_19.tar.bz2` on your workstation, extract, keep `model.int8.onnx` accessible

## Build & install
- [ ] `mise exec -- flutter build apk --debug`
- [ ] `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- [ ] If install is blocked with `INSTALL_FAILED_USER_RESTRICTED`, unlock the phone, accept the prompt, and retry

## Place the model on-device
- [ ] `adb push /path/to/model.int8.onnx /sdcard/Download/model.int8.onnx`

## Navigate to the spike page
- [ ] Launch app
- [ ] Easiest path: run `adb shell am start -W -a android.intent.action.VIEW -d "https://murmur.local/_spike/tts" <package-name>` (if go_router accepts it) OR temporarily add a debug-only button on the Library screen that does `context.go('/_spike/tts');` and remove after sign-off

## Run the spike
- [ ] Tap **"1. Copy assets"** — status shows `assets copied to /data/user/0/.../kokoro-en-v0_19`
- [ ] Tap **"2. Pick model.int8.onnx"** — pick the file you pushed via the system file picker
- [ ] Tap **"3. Synthesize + play"** — within ~1–2 seconds, hear: *"Welcome to murmur. This is how I sound reading your books."* in a female American voice (sid=1, af_bella)
- [ ] Record rough stopwatch latency from tap → first audible sample: **____ ms**
- [ ] Tap **"4. Cancel probe"** — read the monospace output. Expected text includes: `No cancellation primitive found — D-12 fallback path confirmed.`

## Speed probe (optional but recorded in summary)
- [ ] Modify `_synthAndPlay` temporarily to pass `speed: 2.0`, rebuild, replay, observe: does pitch preserve (modern Android AudioTrack time-stretch, expected) or rise chipmunk-style?

## Results to report back
- Pass/fail for each step above
- Observed latency (ms)
- Literal cancel-probe output string
- Speed=2.0 pitch observation (preserved | raised | not tested)
- Any crashes, stack traces, or surprise errors

## Sign-off
Type `spike pass` with the recorded observations inline, or describe the failure to block Phase 4 Wave 1+ planning.
