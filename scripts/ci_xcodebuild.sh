#!/usr/bin/env bash
# Build the app and run the hosted unit-test bundle on a simulator.
# Entitlements are cleared for this CI build so a development team is not required.
# Local runs from Xcode keep the App Group entitlements in the project.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available"
  exit 1
fi

DESTINATION="${DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  if xcrun simctl list devices available | grep -q "iPhone 16 ("; then
    DESTINATION="platform=iOS Simulator,name=iPhone 16"
  else
    NAME="$(xcrun simctl list devices available | grep -E 'iPhone' | head -n 1 | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | sed -E 's/[[:space:]]+$//')"
    if [[ -z "$NAME" ]]; then
      echo "No available iPhone simulator"
      xcrun simctl list devices available || true
      exit 1
    fi
    DESTINATION="platform=iOS Simulator,name=${NAME}"
  fi
fi

echo "Destination: ${DESTINATION}"

xcodebuild test \
  -project MoonlightLofi.xcodeproj \
  -scheme MoonlightLofi \
  -destination "$DESTINATION" \
  -only-testing:MoonlightLofiTests \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_ENTITLEMENTS=""
