#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p logs

main() {
  date -u '+Build started %Y-%m-%dT%H:%M:%SZ'
  # Always require an actual, complete Xcode installation and its iPhoneOS SDK.
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  if [[ ! -d "$DEVELOPER_DIR" ]]; then
    echo "BLOCKED: Full Xcode is missing at $DEVELOPER_DIR. No dylib generated."
    exit 2
  fi
  xcodebuild -version
  SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
  mkdir -p build dist
  # Every build gets a sequence number so old dylibs stay distinguishable.
  VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || true)"
  [[ -n "$VERSION" ]] || { echo "BLOCKED: VERSION file is missing or empty."; exit 2; }
  NAME="LCGridLayout_v${VERSION}"
  OUTPUT="$PROJECT_DIR/build/${NAME}.dylib"
  set -x
  xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -isysroot "$SDK_PATH" \
    -dynamiclib -fobjc-arc -fblocks -O2 -g -Wall -Wextra \
    -Wno-unused-parameter -Wno-deprecated-declarations \
    -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics \
    -framework PhotosUI \
    -install_name @rpath/${NAME}.dylib \
    -Wl,-undefined,error Sources/LCGridLayout.m -o "$OUTPUT"
  codesign --force --sign "${LCGRID_SIGN_IDENTITY:--}" --timestamp=none "$OUTPUT"
  codesign --verify --strict --verbose=2 "$OUTPUT"
  file "$OUTPUT"
  xcrun lipo -archs "$OUTPUT"
  xcrun otool -L "$OUTPUT"
  xcrun otool -l "$OUTPUT" > logs/macho-load-commands.log
  codesign -dvv "$OUTPUT"
  python3 scripts/verify_macho.py "$OUTPUT"
  shasum -a 256 "$OUTPUT"
  cp "$OUTPUT" "dist/${NAME}.dylib"
  ln -sfn "${NAME}.dylib" dist/LCGridLayout.dylib
  set +x
  echo "BUILD VERIFIED -> dist/${NAME}.dylib (dist/LCGridLayout.dylib is a symlink to the latest)"
  echo 'Device loading/UI/coexistence tests remain required; see docs/TESTING.md.'
}

# Pipe through tee so the full log lands in logs/build.log without relying on
# process substitution (<(...) / >(...)), which restricted shells may refuse.
# set -e + pipefail abort the script on the first failing step (no false success).
main 2>&1 | tee logs/build.log
