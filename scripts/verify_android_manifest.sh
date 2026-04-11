#!/usr/bin/env bash
# Verifies Phase 1 AndroidManifest.xml matches the expected permission allow-list.
# Exit 0 on success, non-zero on any violation.

set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: $MANIFEST does not exist"
  exit 1
fi

fail=0

# Required permissions (must be present)
required=(
  "android.permission.FOREGROUND_SERVICE"
  "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"
  "android.permission.POST_NOTIFICATIONS"
)

for perm in "${required[@]}"; do
  if ! grep -q "$perm" "$MANIFEST"; then
    echo "FAIL: required permission missing: $perm"
    fail=1
  fi
done

# Forbidden permissions (must NOT be present in Phase 1)
forbidden=(
  "android.permission.INTERNET"
  "android.permission.READ_MEDIA_AUDIO"
  "android.permission.READ_EXTERNAL_STORAGE"
  "android.permission.WRITE_EXTERNAL_STORAGE"
)

for perm in "${forbidden[@]}"; do
  if grep -q "$perm" "$MANIFEST"; then
    echo "FAIL: forbidden permission present: $perm (not allowed in Phase 1)"
    fail=1
  fi
done

# android:label must be Murmur (D-02)
if ! grep -q 'android:label="Murmur"' "$MANIFEST"; then
  echo "FAIL: android:label is not \"Murmur\" (expected per D-02)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: AndroidManifest.xml matches Phase 1 allow-list"
  exit 0
else
  exit 1
fi
