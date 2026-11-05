#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Minefield - 自動化測試腳本 (test.sh)
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 確保 DEVELOPER_DIR 指向完整 Xcode 工具鏈（支援 XCTest）
if [ -z "${DEVELOPER_DIR:-}" ]; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

echo -e "${BLUE}==> 執行 Minefield 自動化測試套件 (ARM64)...${NC}"

# 執行測試並啟用並行測試
if swift test --arch arm64 --parallel; then
    echo -e "${GREEN}✓ 所有測試通過！${NC}"
else
    echo -e "${RED}✗ 測試失敗，請檢查上方錯誤輸出。${NC}"
    exit 1
fi
