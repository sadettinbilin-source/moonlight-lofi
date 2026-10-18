#!/usr/bin/env bash
# Build Moonlight Lofi and run unit plus UI tests on one iPhone simulator.
# Entitlements are cleared so a signing team is not required.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available"
  exit 1
fi

SELECTION="$(bash scripts/select_simulator.sh)"
UDID="${SELECTION%%$'\t'*}"
NAME="${SELECTION#*$'\t'}"
echo "Destination: ${NAME} (${UDID})"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

RESULT="${RESULT_BUNDLE:-$PWD/TestResults.xcresult}"
rm -rf "$RESULT"

xcodebuild test \
  -project MoonlightLofi.xcodeproj \
  -scheme MoonlightLofi \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_ENTITLEMENTS=""
