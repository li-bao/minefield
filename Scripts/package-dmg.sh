#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Minefield - Apple Silicon DMG 封裝腳本 (package-dmg.sh)
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
DMG_NAME="Minefield-AppleSilicon.dmg"
DMG_OUTPUT="${DIST_DIR}/${DMG_NAME}"
DMG_STAGE="${BUILD_DIR}/dmg_staging"

# 確保 DEVELOPER_DIR
if [ -z "${DEVELOPER_DIR:-}" ]; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE} Minefield DMG 封裝程序 (Apple Silicon)${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. 確保 App 已建置
if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${YELLOW}未偵測到現有 App Bundle，開始執行建置程序...${NC}"
    "${ROOT_DIR}/Scripts/build.sh"
fi

# 2. 準備暫存目錄
echo -e "${YELLOW}[1/4] 準備 DMG 打包暫存目錄...${NC}"
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
mkdir -p "${DIST_DIR}"

# 3. 複製 App Bundle 並建立 /Applications 捷徑
echo -e "${YELLOW}[2/4] 複製 App Bundle 與建立 Applications 連結...${NC}"
cp -R "${APP_BUNDLE}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

# 4. 使用 hdiutil 建立唯讀壓縮 DMG
echo -e "${YELLOW}[3/4] 產生 Apple Silicon 專用 UDZO DMG 映像檔...${NC}"
rm -f "${DMG_OUTPUT}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${DMG_OUTPUT}"

# 5. 清理與驗證產物
echo -e "${YELLOW}[4/4] 清理暫存檔並驗證 DMG...${NC}"
rm -rf "${DMG_STAGE}"

if [ -f "${DMG_OUTPUT}" ]; then
    DMG_SIZE=$(du -h "${DMG_OUTPUT}" | cut -f1)
    SHA256=$(shasum -a 256 "${DMG_OUTPUT}" | cut -d ' ' -f 1)
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}🎉 DMG 封裝完成！${NC}"
    echo -e "檔案路徑: ${DMG_OUTPUT}"
    echo -e "檔案大小: ${DMG_SIZE}"
    echo -e "SHA256:   ${SHA256}"
    echo -e "${GREEN}==========================================${NC}"
else
    echo -e "${RED}錯誤: DMG 建立失敗${NC}"
    exit 1
fi
