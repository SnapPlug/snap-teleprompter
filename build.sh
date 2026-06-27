#!/bin/bash
# Build Snap Teleprompter using only Command Line Tools (no Xcode.app required)
# Usage: bash build.sh

set -e

APP="SnapTeleprompter"
BUNDLE="${APP}.app"
SDK=$(xcrun --show-sdk-path --sdk macosx)
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"

echo "→ Building ${APP} for ${TARGET}..."

rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"

swiftc \
    Sources/SnapTeleprompterApp.swift \
    Sources/MainView.swift \
    Sources/NotchWindowController.swift \
    Sources/OnboardingView.swift \
    Sources/TeleprompterOverlay.swift \
    Sources/TeleprompterViewModel.swift \
    -sdk "${SDK}" \
    -target "${TARGET}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -framework CoreText \
    -O \
    -o "${BUNDLE}/Contents/MacOS/${APP}"

cp Info.plist "${BUNDLE}/Contents/Info.plist"

# Copy app icon
if [ -f "Resources/AppIcon.icns" ]; then
    mkdir -p "${BUNDLE}/Contents/Resources"
    cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "✓ ${BUNDLE} 생성 완료"
echo "  실행: open ${BUNDLE}"
echo ""
echo "  처음 실행 시 Gatekeeper 경고가 뜨면:"
echo "  Finder에서 앱을 우클릭 → 열기 → 열기"
