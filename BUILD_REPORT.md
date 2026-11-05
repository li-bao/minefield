# Minefield 原生 macOS (Apple Silicon) 建置報告

本報告詳細記錄 **Minefield** 原生 macOS 掃雷遊戲的 Release 編譯、App Bundle 封裝、圖示打包、Ad-hoc 程式碼簽署與 Apple Silicon DMG 建立之完整驗證資訊。

---

## 1. 系統與編譯環境

| 項目 | 規格 / 版本 |
| :--- | :--- |
| **主機硬體架構** | Apple Silicon ARM64 (`arm64`) |
| **作業系統** | macOS 27.0.1 (Build 26A434) |
| **Swift 編譯器** | Apple Swift version 6.4 (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`) |
| **Target 平台** | `arm64-apple-macos14.0` (向下相容至 macOS 14.0 Sonoma) |
| **macOS SDK** | `MacOSX27.0.sdk` |
| **開發工具鏈** | Xcode 27 / Command Line Tools (純原生系統工具鏈) |
| **第三方依賴** | **零第三方套件依賴** (純 Swift 6、SwiftUI、AppKit、XCTest) |

---

## 2. 自動化建置管線與產物

本專案建置與打包程序完全由標準化 Shell 腳本驅動：
- `Scripts/build.sh`: 執行 Release 編譯、組裝 App Bundle、複製圖示、組態 `Info.plist` 與執行 Ad-hoc 程式碼簽章。
- `Scripts/package-dmg.sh`: 建立 Staging 目錄、配置 `/Applications` 軟連結、使用 `hdiutil` 產生唯讀壓縮 UDZO DMG 檔案。

### 交付產物清單

1. **macOS 應用程式目錄 (App Bundle)**：
   - 路徑：`dist/Minefield.app`
   - 二進位檔架構：`Mach-O 64-bit executable arm64` (單一 arm64 純原生架構，無 x86_64 二進位冗餘)
   - 二進位檔大小：約 5.8 MB
   - 封裝結構：
     ```text
     Minefield.app/
     └── Contents/
         ├── Info.plist
         ├── MacOS/
         │   └── Minefield (可執行檔，權限 755)
         ├── PkgInfo (內容: APPL????)
         └── Resources/
             ├── Minefield.icns (787 KB，包含 16x16 至 1024x1024 Retina 各尺寸)
             └── AppIcon.icns (787 KB 相容備援)
     ```

2. **Apple Silicon 安裝磁碟映像檔 (DMG)**：
   - 路徑：`dist/Minefield-AppleSilicon.dmg`
   - 格式：`UDZO` (zlib 壓縮唯讀磁碟映像)
   - 檔案大小：約 3.2 MB
   - SHA-256 雜湊碼：`ac6d96cf0fb3459e035a136048ac39519200a5ffe6b95d637fe31fda26ae79ee`
   - 卷宗名稱：`Minefield`
   - 內容物：`Minefield.app`、`/Applications` 捷徑

---

## 3. Info.plist 配置驗證

透過 `plutil -lint` 驗證合格，重要鍵值宣告如下：

| Key | 設定值 | 說明 |
| :--- | :--- | :--- |
| `CFBundleExecutable` | `Minefield` | 主執行程式檔名 |
| `CFBundleIdentifier` | `com.minefield.macos` | 應用程式唯一識別碼 |
| `CFBundleName` | `Minefield` | 應用程式名稱 |
| `CFBundleDisplayName` | `Minefield 掃雷` | 繁體中文顯示名稱 |
| `CFBundlePackageType` | `APPL` | 應用程式 Bundle 類型 |
| `CFBundleShortVersionString` | `1.0.0` | 發行版本號 |
| `CFBundleVersion` | `1` | 內部組置版本號 |
| `CFBundleIconFile` | `Minefield.icns` | 圖示指定檔案 |
| `LSMinimumSystemVersion` | `14.0` | 最低支援 macOS 版本 |
| `NSHighResolutionCapable` | `true` | 支援高解析度 Retina 顯示 |
| `CFBundleDevelopmentRegion` | `zh_TW` | 預設繁體中文語系 |

---

## 4. 程式碼簽章 (Code Signing) 驗證

依據 Phase 5 交付準則，採用符合 Apple Silicon 本地安全機制的 Ad-hoc 簽名，不偽造 Developer ID 亦不宣稱未完成之 Apple 公證：

```bash
$ codesign -dvvv dist/Minefield.app
Executable=/Users/libao/Downloads/minefield/dist/Minefield.app/Contents/MacOS/Minefield
Identifier=com.minefield.macos
Format=app bundle with Mach-O thin (arm64)
CodeDirectory v=20400 size=12172 flags=0x2(adhoc) hashes=374+3 location=embedded
Hash type=sha256 size=32
CandidateCDHash sha256=63c3391361baff18d09a28ddf249be2c1de7994b
CDHash=63c3391361baff18d09a28ddf249be2c1de7994b
Signature=adhoc
Sealed Resources version=2 rules=13 files=2
```

嚴格簽章完整性檢查：
```bash
$ codesign --verify --deep --strict dist/Minefield.app
# 輸出無任何錯誤 (驗證通過)
```

---

## 5. 圖示生成與封裝驗證

使用專屬 Swift 圖形生成器 (`Scripts/generate_icon.swift`) 透過 `NSBitmapImageRep` 與 CoreGraphics 繪製高解析度 1024x1024 原生圖示：
- **視覺主題**：石墨黑深邃底色、柔和同心圓雷達紋理、幾何精確的八向多邊形地雷刺柱、發光青綠 (`#00FFAA`) 與電光紫 (`#7A22FF`) 雙環核心反應堆，搭配金屬高光與邊框。
- **解析度矩陣**：經由 `sips` 轉出標準 10 種解析度（16x16、32x32、64x64、128x128、256x256、512x512、1024x1024，含 1x 與 2x Retina 像素）。
- **封裝**：經 `iconutil -c icns` 編譯為 Apple 原生 `Minefield.icns` (787 KB)，完全相容 macOS Finder 與 Dock 圖示彩現。

---

## 6. 二進位架構檢測

```bash
$ file dist/Minefield.app/Contents/MacOS/Minefield
dist/Minefield.app/Contents/MacOS/Minefield: Mach-O 64-bit executable arm64

$ lipo -info dist/Minefield.app/Contents/MacOS/Minefield
Non-fat file: dist/Minefield.app/Contents/MacOS/Minefield is architecture: arm64
```

確認為純粹之 64-bit ARM64 原生二進位架構，無 Rosetta 2 轉譯開銷。
