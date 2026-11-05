#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Minefield - 開發環境檢查與初始化腳本 (bootstrap.sh)
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo " Minefield - 檢查 Apple Silicon 開發環境"
echo "=========================================="

# 1. 檢查硬體架構
ARCH=$(uname -m)
echo -n "[1/8] 檢查 CPU 架構: "
if [ "$ARCH" = "arm64" ]; then
    echo -e "${GREEN}通過 (Apple Silicon arm64)${NC}"
else
    echo -e "${RED}失敗: 目前架構為 $ARCH，Minefield 專案優先針對 Apple Silicon (arm64) 優化${NC}"
    exit 1
fi

# 2. 檢查 macOS 版本
OS_VERSION=$(sw_vers -productVersion)
echo -n "[2/8] 檢查 macOS 版本: "
MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d. -f1)
if [ "$MAJOR_VERSION" -ge 14 ]; then
    echo -e "${GREEN}通過 (macOS $OS_VERSION)${NC}"
else
    echo -e "${YELLOW}警告: 目前版本為 $OS_VERSION。建議在 macOS 14.0 (Sonoma) 或更高版本上執行${NC}"
fi

# 3. 檢查 Xcode Command Line Tools
echo -n "[3/8] 檢查 Command Line Tools: "
if xcode-select -p >/dev/null 2>&1; then
    CLT_PATH=$(xcode-select -p)
    echo -e "${GREEN}通過 ($CLT_PATH)${NC}"
else
    echo -e "${RED}未安裝。請執行 'xcode-select --install'${NC}"
    exit 1
fi

# 4. 檢查 Swift 編譯器
echo -n "[4/8] 檢查 Swift 編譯器: "
if command -v swift >/dev/null 2>&1; then
    SWIFT_VER=$(swift --version | head -n 1)
    echo -e "${GREEN}通過 ($SWIFT_VER)${NC}"
else
    echo -e "${RED}找不到 Swift 編譯器${NC}"
    exit 1
fi

# 5. 檢查 Swift Package Manager
echo -n "[5/8] 檢查 Swift Package Manager: "
if swift package --version >/dev/null 2>&1; then
    echo -e "${GREEN}通過${NC}"
else
    echo -e "${RED}找不到 SPM 工具${NC}"
    exit 1
fi

# 6. 檢查 macOS SDK
echo -n "[6/8] 檢查 macOS SDK: "
if xcrun --show-sdk-path >/dev/null 2>&1; then
    SDK_PATH=$(xcrun --show-sdk-path)
    SDK_VER=$(xcrun --show-sdk-version)
    echo -e "${GREEN}通過 (macOS SDK $SDK_VER @ $SDK_PATH)${NC}"
else
    echo -e "${RED}找不到 macOS SDK${NC}"
    exit 1
fi

# 7. 檢查 Git 版本管理工具
echo -n "[7/8] 檢查 Git: "
if command -v git >/dev/null 2>&1; then
    GIT_VER=$(git --version)
    echo -e "${GREEN}通過 ($GIT_VER)${NC}"
else
    echo -e "${RED}找不到 Git${NC}"
    exit 1
fi

# 8. 檢查原生封裝工具鏈 (hdiutil, codesign, iconutil, sips)
echo -n "[8/8] 檢查系統原生打包工具 (hdiutil, codesign, iconutil, sips): "
MISSING_TOOLS=()
for tool in hdiutil codesign iconutil sips; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${GREEN}通過 (全部就緒)${NC}"
else
    echo -e "${RED}缺少以下工具: ${MISSING_TOOLS[*]}${NC}"
    exit 1
fi

# 設定腳本執行權限
chmod +x "$(dirname "$0")"/*.sh

echo "=========================================="
echo -e "${GREEN}🎉 環境檢查完成，所有必要工具均已就緒！${NC}"
echo "=========================================="
