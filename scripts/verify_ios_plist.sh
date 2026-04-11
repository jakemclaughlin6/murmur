#!/usr/bin/env bash
# Verifies Phase 1 ios/Runner/Info.plist contains every FND-07 compliance key.
# Works on Linux (no plutil) and macOS. Exit 0 on success, non-zero on violation.

set -euo pipefail

PLIST="ios/Runner/Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "FAIL: $PLIST does not exist"
  exit 1
fi

fail=0

check_key_value() {
  local key="$1"
  local value_pattern="$2"
  local description="$3"
  # grep -A 1 for the key, then check the next line matches value_pattern
  if ! grep -A 1 "<key>${key}</key>" "$PLIST" | grep -q "$value_pattern"; then
    echo "FAIL: ${description} — expected <key>${key}</key> followed by ${value_pattern}"
    fail=1
  fi
}

check_key_present() {
  local key="$1"
  local description="$2"
  if ! grep -q "<key>${key}</key>" "$PLIST"; then
    echo "FAIL: ${description} — key <${key}> not present"
    fail=1
  fi
}

# CFBundleDisplayName = Murmur (D-02)
check_key_value "CFBundleDisplayName" "<string>Murmur</string>" "Display name must be 'Murmur'"

# Bundle identifier must remain $(PRODUCT_BUNDLE_IDENTIFIER) — NOT hard-coded
check_key_value "CFBundleIdentifier" '\$(PRODUCT_BUNDLE_IDENTIFIER)' "Bundle identifier must be \$(PRODUCT_BUNDLE_IDENTIFIER) variable"

# FND-07 keys
check_key_present "UIBackgroundModes" "FND-07: background audio mode"
if ! grep -A 2 "<key>UIBackgroundModes</key>" "$PLIST" | grep -q "<string>audio</string>"; then
  echo "FAIL: FND-07: UIBackgroundModes must contain <string>audio</string>"
  fail=1
fi

check_key_value "UIFileSharingEnabled" "<true/>" "FND-07: UIFileSharingEnabled must be true"
check_key_value "LSSupportsOpeningDocumentsInPlace" "<true/>" "FND-07: LSSupportsOpeningDocumentsInPlace must be true"

check_key_present "CFBundleDocumentTypes" "FND-07: EPUB document type"
if ! grep -q "org.idpf.epub-container" "$PLIST"; then
  echo "FAIL: FND-07: CFBundleDocumentTypes must reference org.idpf.epub-container"
  fail=1
fi

check_key_value "ITSAppUsesNonExemptEncryption" "<false/>" "FND-07: ITSAppUsesNonExemptEncryption must be false (no non-exempt crypto in Phase 1)"

if [ "$fail" -eq 0 ]; then
  echo "OK: ios/Runner/Info.plist has all Phase 1 FND-07 keys"
  exit 0
else
  exit 1
fi
