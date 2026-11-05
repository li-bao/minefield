#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Minefield - 原生 macOS App 建置腳本 (build.sh)
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="Minefield"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DIST_APP="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 確保 DEVELOPER_DIR 指向完整 Xcode 工具鏈（若已安裝）
if [ -z "${DEVELOPER_DIR:-}" ]; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE} Minefield 原生 macOS App 建置程序 (ARM64)${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. 執行 SPM Release 建置 (針對 arm64)
echo -e "${YELLOW}[1/6] 編譯 Swift 原始碼 (Release - arm64)...${NC}"
cd "${ROOT_DIR}"
swift build -c release --arch arm64

BIN_DIR=$(swift build -c release --arch arm64 --show-bin-path)
EXECUTABLE="${BIN_DIR}/${APP_NAME}"

if [ ! -f "${EXECUTABLE}" ]; then
    echo -e "${RED}錯誤: 編譯產物不存在於 ${EXECUTABLE}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 編譯成功: ${EXECUTABLE}${NC}"

# 2. 建立 .app 目錄結構
echo -e "${YELLOW}[2/6] 建立 App Bundle 結構...${NC}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. 複製執行檔與資源
echo -e "${YELLOW}[3/6] 安裝二進位檔與資源...${NC}"
cp "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 寫入 PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 寫入 Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>Minefield.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.minefield.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Minefield 掃雷</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Minefield. All rights reserved.</string>
</dict>
</plist>
EOF

# 安裝圖示
if [ -f "${ROOT_DIR}/Resources/Icons/Minefield.icns" ]; then
    cp "${ROOT_DIR}/Resources/Icons/Minefield.icns" "${RESOURCES_DIR}/Minefield.icns"
    cp "${ROOT_DIR}/Resources/Icons/Minefield.icns" "${RESOURCES_DIR}/AppIcon.icns"
elif [ -f "${ROOT_DIR}/Resources/Icons/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Resources/Icons/AppIcon.icns" "${RESOURCES_DIR}/Minefield.icns"
fi

# 4. 程式碼簽章 (Ad-hoc 簽署)
echo -e "${YELLOW}[4/6] 執行 Ad-hoc 程式碼簽署...${NC}"
codesign --force --deep --sign - "${APP_BUNDLE}"

# 5. 驗證簽章與架構
echo -e "${YELLOW}[5/6] 驗證二進位檔架構與簽名完整性...${NC}"
file "${MACOS_DIR}/${APP_NAME}"
lipo -info "${MACOS_DIR}/${APP_NAME}"
codesign --verify --deep --strict "${APP_BUNDLE}"

# 6. 同步至 dist/ 目錄
echo -e "${YELLOW}[6/6] 複製交付檔至 dist/ 目錄...${NC}"
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_APP}"
cp -R "${APP_BUNDLE}" "${DIST_APP}"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}🎉 建置成功！產物位置:${NC}"
echo -e "${GREEN}  - ${APP_BUNDLE}${NC}"
echo -e "${GREEN}  - ${DIST_APP}${NC}"
echo -e "${GREEN}==========================================${NC}"
