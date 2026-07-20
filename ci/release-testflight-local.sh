#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${APPLE_TEAM_ID:-2V7W69N399}"
ASC_KEY_ID="${ASC_KEY_ID:-XS4DNNPK82}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de74-5cd4-47e3-e053-5b8c7c11a4d1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/AuthKey_${ASC_KEY_ID}.p8}"
MARKETING_VERSION="${MARKETING_VERSION:-0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/TestFlight}"
ARCHIVE_PATH="$OUTPUT_DIR/Botanic-${BUILD_NUMBER}.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export-${BUILD_NUMBER}"
EXPORT_OPTIONS_PATH="$OUTPUT_DIR/ExportOptions-${BUILD_NUMBER}.plist"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "Missing App Store Connect key: $ASC_KEY_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Using Xcode:"
xcodebuild -version

echo "Generating project..."
xcodegen generate

echo "Running shared unit tests..."
swift test --package-path BotanicKit

cat > "$EXPORT_OPTIONS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key><string>upload</string>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>stripSwiftSymbols</key><true/>
  <key>uploadSymbols</key><true/>
  <key>testFlightInternalTestingOnly</key><false/>
</dict>
</plist>
PLIST

echo "Archiving build $BUILD_NUMBER..."
xcodebuild \
  -project Botanic.xcodeproj \
  -scheme Botanic \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  archive

echo "Uploading to App Store Connect/TestFlight..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "Done. Uploaded build $BUILD_NUMBER for version $MARKETING_VERSION."
