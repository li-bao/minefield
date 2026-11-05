# Minefield 開發進度記錄 (Development Progress)

## 專案資訊
- **專案名稱**：Minefield
- **Bundle ID**：`com.minefield.macos`
- **目標平台**：macOS 14.0+ (Sonoma 及後續版本)
- **架構**：Apple Silicon (ARM64 原生)
- **主要語言**：繁體中文 (Traditional Chinese)

---

## 各階段進度看板

| 階段 | 內容重點 | 狀態 | 備註 |
|---|---|---|---|
| **Phase 1** | **專案初始化、環境檢查、架構骨幹與自動化腳本** | **已完成 (Completed)** | 8 項系統工具通過、初次 ARM64 編譯通過、XCTest 通過、DMG 打包驗證成功 |
| **Phase 2** | **純 Swift 掃雷核心引擎、狀態機、安全開局與懲罰模式** | **已完成 (Completed)** | 14/14 項 XCTest 通過、純 Swift 解耦架構、3x3 安全區、Flood Fill、Chording、經典/懲罰模式 |
| **Phase 3** | **原生 macOS UI/UX、主選單、格子手勢分流、自訂棋盤與設定面板** | **已完成 (Completed)** | 原生 SwiftUI + AppKit 手勢容器、長按/短按無衝突防護、深色/淺色外觀、自適應棋盤、DMG 打包驗收 |
| **Phase 4** | **Smart Solver 數學邏輯求解器、提示系統與本地 Ollama AI** | **已完成 (Completed)** | 23/23 項 XCTest 通過、CSP 連通分群回溯、50/50 辨識、本地 Ollama 專家解盤、AI 安全驗證防護層 |
| **Phase 4.5** | **動態智慧棋局生成、事務性棋局修復與防猜系統 (Dynamic AI Board)** | **已完成 (Completed)** | 31/31 項 XCTest 通過、Classic / No-Guess / AI Expert 三模式、No-Guess 生成器、覆蓋足跡等價修復、動態防猜、推論歷程回溯 |
| **Phase 4.75** | **終極功能擴充、AI 智慧教練、棋局管理與完整遊戲系統** | **已完成 (Completed)** | 43/43 項 XCTest 通過、六大遊戲模式、AI 解題教練、What-if 實驗室、風險熱力圖、AutoPlay、Undo/Redo、Replay、每日挑戰、成就統計、難度評估、沙盒、6套主題、原生音效 |
| Phase 5 | 綜合端對端測試、DMG 發布包裝與最終驗收交付 | 待進行 | 即將進行 |

---

## Phase 1 執行細節記錄

### 1. 開發環境檢查結果
- **CPU 架構**：`arm64` (Apple Silicon 原生，確認無 Intel 轉譯)
- **macOS 版本**：`macOS 27.0.1` (Build `26A434`)
- **Xcode 工具鏈**：
  - Command Line Tools: `/Library/Developer/CommandLineTools`
  - Xcode.app: `/Applications/Xcode.app` (Xcode 27.2)
  - SDK: `macOS SDK 27.0`
- **Swift 編譯器**：`Swift 6.4` (Target: `arm64-apple-macosx27.0.0`)
- **Swift Package Manager**：SPM 6.4 正常就緒
- **版本控制**：`git 2.54.0`
- **系統打包工具**：
  - `hdiutil`：OK (`/usr/bin/hdiutil`)
  - `codesign`：OK (`/usr/bin/codesign`)
  - `iconutil`：OK (`/usr/bin/iconutil`)
  - `sips`：OK (`/usr/bin/sips`)

### 2. 交付成果產物
- [x] 標準目錄結構（`App`、`Models`、`GameEngine`、`Solver`、`AI`、`Views`、`Components`、`Services`、`Settings`、`Utilities`）
- [x] Swift 模組與資料結構定義（`Cell`、`Board`、`GameDifficulty`、`GameSettings`）
- [x] 自動化建置腳本：
  - `Scripts/bootstrap.sh`（環境自我檢測腳本）
  - `Scripts/test.sh`（自動化並行單元測試腳本）
  - `Scripts/build.sh`（Release ARM64 應用程式封裝與 Ad-hoc 簽章）
  - `Scripts/package-dmg.sh`（Apple Silicon DMG 磁碟映像打包）
- [x] 高解析度 macOS 原生圖示（`Resources/Icons/AppIcon.icns`）
- [x] 架構設計文件（`docs/ARCHITECTURE.md`）
- [x] 繁體中文說明文件（`README.md`）
- [x] 首次成功編譯：`build/Minefield.app` (Mach-O 64-bit executable arm64)
- [x] 首次成功測試：4/4 項單元測試 100% 通過
- [x] 首次成功打包：`dist/Minefield-AppleSilicon.dmg` (UDZO 壓縮映像檔，掛載測試通過)

---

## Phase 2 執行細節記錄 (純 Swift 掃雷引擎)

### 1. 核心模型與狀態分離
- **`CellState`**：`hidden` (未翻開), `flagged` (已插旗), `revealed` (已翻開安全數字), `exploded` (踩爆地雷)。
- **`Cell` vs `PublicCell`**：
  - `Cell`：內部完整資料，掌握實際地雷位置與相鄰統計。
  - `PublicCell`：外部投影視圖，嚴格保護未翻開格子的地雷機密，徹底杜絕 AI 與 Solver 作弊可能。
- **`Board`**：提供 8 方向座標探測、旗幟統計、安全格數量計算與矩陣投影。

### 2. 難度規格與即時驗證
- **Beginner**：9 × 9，10 顆地雷。
- **Intermediate**：16 × 16，40 顆地雷。
- **Expert**：30 × 16，99 顆地雷。
- **Custom (自訂難度)**：
  - 寬度：5 ～ 40。
  - 高度：5 ～ 30。
  - 地雷數限制：`1 ... (width * height - 9)`（嚴格保證首發 3×3 安全區成立）。
  - `CustomBoardConfig.validate()`：即時錯誤枚舉回報（`widthOutOfRange` / `heightOutOfRange` / `minesOutOfRange`）。

### 3. 首步 3×3 安全機制與延遲佈局
- 採用 **Lazy Mine Deployment**：在首發點擊時以首點座標為中心劃定 3×3 禁雷防護區，再將地雷分配至候選座標。
- 極限盤面防禦：若自訂地雷極端密集，安全區自動安全退化至首點單格，保證首步永遠安全。
- 支援確定性 PRNG：透過 `SeededRandom (SplitMix64)` 達成棋盤 100% 重現與單元測試比對。

### 4. 操作與連鎖展開演算法
- **點擊翻開**：禁止翻開已插旗或已揭露格子。
- **插旗與取消**：即時更新剩餘旗幟計數 (`remainingMinesToFlag`)。
- **快捷翻開 (Chording)**：點擊已翻開數字格，若周圍已插旗數 == 該格數字，自動展開未插旗相鄰格。
- **廣度優先 Flood Fill**：翻開 0 數字格時向外連鎖展開，嚴格阻絕覆蓋已插旗格子 (`flagged`)。

### 5. 雙模式計時與懲罰
- **懲罰模式 (Penalty Mode - 預設)**：
  - 踩雷不直接死亡，格子標為 `.exploded`。
  - 踩雷次數累加 (`explodedMineCount += 1`)。
  - 總成績秒數 = 遊玩時間 + 踩雷次數 × 懲罰時間 (預設 30.0s，可自訂)。
  - 遊戲持續，翻開其餘安全格依然可獲勝。
- **經典模式 (Classic Mode)**：
  - 踩中任何地雷立即判負 (`state = .lost`)，並自動揭露剩餘所有地雷。

### 6. XCTest 驗證成果
- **測試項目總數**：14 項測試全部通過 (0 警告、0 錯誤)。
- **涵蓋項目**：難度配置、自訂驗證、地雷數量精準度、3x3 首擊安全區、角落首擊、鄰近雷數準確度、插旗阻擋、Flood Fill 旗幟防護、Chording 快捷翻開、經典模式失敗揭露、懲罰模式計時、不要求插滿地雷之勝利判定、Seed 重現性、資訊隱藏防作弊。

---

## Phase 3 執行細節記錄 (原生 macOS UI / UX)

### 1. 高級感視覺與色彩主題
- **設計風格**：深色石墨黑 (`#14171F`)、深藍與靛紫、淡青綠色強調色 (`#2DD4BF`)、柔和漸層與陰影。
- **色彩適應**：全站實作 `ColorTheme`，支援系統外觀、深色模式 (Dark Mode) 與淺色模式 (Light Mode)。
- **數字排版**：1～8 經典高辨識度色彩，搭配圓體加粗數字 (`.design: .rounded`)。

### 2. 精緻格子視覺與狀態渲染
- **Hidden**：微凸起晶透方格，帶頂部微光與底部陰影。
- **Revealed**：平面內嵌凹陷質感，清晰區隔安全數字與空白格。
- **Flagged**：琥珀金色旗幟與彈簧彈出動畫。
- **Exploded**：烈焰紅橙漸層發光 (`#EF4444`) 與爆炸破裂圖示。

### 3. AppKit 滑鼠事件分流容器 (`MouseInteractionView`)
- **左鍵短按**：點擊未翻開格立即翻開 (`revealCell`)；點擊數字格觸發 Chording 連鎖翻開。
- **左鍵長按 (>= 0.45s 可設定)**：即時插旗或取消插旗 (`toggleFlag`)，並附帶微動態進度光環與觸覺反饋。
- **滑鼠右鍵**：即刻插旗/取消插旗。
- **防衝突機制**：藉由 AppKit `CustomMouseNSView` 的 `didTriggerLongPress` 狀態守護，確保長按插旗完成後絕不會在放開滑鼠時誤觸發短按翻開！

### 4. 遊戲介面與自適應棋盤
- **頂部狀態列 (`GameHeaderView`)**：地雷剩餘倒數、動態狀態表情按鈕 (可重開)、計時器與踩雷懲罰標記 (`+30s`)。
- **自適應棋盤 (`BoardGridView`)**：動態依視窗空間計算格子尺寸 (24~44px)；面對 30×16 高級或 40×30 自訂棋盤時自動啟用雙向平滑滾動，視窗不被撐爆。
- **底部面板 (`SideControlPanelView`)**：當前難度模式、安全格揭露進度百分比、即時狀態指引、智慧排雷提示按鈕。

### 5. 自訂棋盤與設定面板
- **`CustomBoardSheet`**：
  - 寬度 (5~40)、高度 (5~30)、雷數滑桿與步進器。
  - 即時計算地雷密度百分比，動態標註難度等級（休閒輕度、標準均衡、高難度挑戰、極限地獄）。
  - 即時合法性校驗與防呆錯誤提示。
- **`SettingsSheet`**：
  - 外觀切換（跟隨系統 / 深色 / 淺色）。
  - 規則模式（懲罰模式 vs 經典模式）與懲罰秒數設定 (10~60s)。
  - 長按插旗時間微調 (0.30s ~ 0.80s)。
  - 視聽效果開關與本地 Ollama API 配置入口。

### 6. macOS 原生體驗與驗收
- 原生選單與快捷鍵：`Cmd+R` 重新開始、`Cmd+1/2/3` 切換難度。
- 完整 VoiceOver 語音無障礙標籤。
- 實際啟動 `Minefield.app` (PID: 5632) 驗證進程正常載入，並封裝全新 DMG 交付檔。

---

## Phase 4 執行細節記錄 (Smart Solver、提示系統與 Ollama AI)

### 1. 雙引擎架構 (獨立互不取代)
- **模組 A (內建數學 CSP 求解器)**：純 Swift 演算法，在離線無任何相依時保證 100% 精準度。
- **模組 B (本機 Ollama AI 專家)**：本地 LLM 自然語言解盤，提供大局觀與直觀人類決策建議。
- **防作弊機制**：兩者皆只能透過 `PublicCell` 安全視圖存取資訊，絕不觸碰內部機密雷區。

### 2. 命題邏輯約束與 CSP 演算法
- **基礎邏輯**：單格直接推導、已知地雷標記、全剩餘地雷背景機率估計。
- **集合包含推理 (Subset Deduction)**：若 $S_1 \subseteq S_2$，由約束相減得出差集地雷數，有效解開 1-2-1 等經典邊界棋型。
- **CSP 連通分群回溯**：
  - 將活躍未知變數與約束切割為獨立連通區塊 (Connected Components)。
  - 每個區塊獨立執行剪枝 DFS / Backtracking，統計所有合法排列之頻率。
  - 資源上限守護：搜尋節點超過限制 (`maxSearchNodes = 20,000`) 時標記 `isIncomplete = true`，絕不將殘缺推導當作確定結論。
- **死局與猜測識別**：
  - 若盤面全為 50/50 對稱死局或無必然安全步，明確標示 `GUESS_REQUIRED`，提供客觀最低風險格。

### 3. 雙層提示系統 (Hint System)
- **優先順序**：必然安全格 (0% 風險) $\to$ 必然地雷格 (100% 風險，建議插旗) $\to$ 最低風險格 (附帶精確機率)。
- **操作分離**：提供「僅在地圖上高亮顯示」與「套用此提示」，嚴格不經玩家同意擅自替玩家執行動作。

### 4. 本地 Ollama 服務與專家推論
- 支援 `GET /api/tags`（動態取得已安裝模型）與 `POST /api/chat`（`stream=false`, `format="json"`）。
- 全流程非同步 `async/await`，支援任務取消，推論期間遊戲畫面與動畫流暢無延遲。
- 嚴格限定本地主機，若設定非本機端點自動亮起安全隱私警語。

### 5. 嚴格的 AI 安全驗證防護層
- 程式防護層對 AI 回傳的每個建議進行硬性檢驗：
  - 座標越界 $\to$ 標記 `rejected` 並拒絕執行。
  - 格子已翻開或已插旗 $\to$ 標記 `rejected` 並拒絕執行。
  - 交叉驗證 Solver 機率真值：若 Solver 證明安全則標記 `verifiedSafe`；若 Solver 無法證明則強制標記為 `speculation` (AI 啟發式推測)，並呈現真正的 CSP 風險機率。

### 6. XCTest 測試覆蓋
- 23 項 XCTest 單元測試 100% 通過（含 9 項 Phase 4 專屬邏輯測試）。

---

## Phase 4.5 執行細節記錄 (動態智慧棋局生成、修復與防猜系統)

### 1. 三種遊戲模式劃分 (`GameMode`)
- **經典模式 (Classic Mode)**：地雷位置在首次安全點擊後即完全固定，不允許系統動態調整或修復棋盤，保留最純粹的經典掃雷考驗。
- **無猜模式 (No-Guess Mode)**：開局透過模擬器驗證保證存在一條純邏輯解題路徑，且在遊玩過程中持續啟用「動態防猜機制」，當玩家操作導致不可避免的猜測時，自動事務性微調隱藏雷區，消除猜測。
- **AI 專家模式 (AI Expert Mode)**：整合本地 Ollama AI 專家分析、可視化棋局修復預覽（雙重確認機制）、全自動單步邏輯排雷 (`Auto-Solve`) 與可推理解釋歷程追蹤。

### 2. No-Guess 棋局生成器 (`NoGuessBoardGenerator`)
- 結合 `SmartSolver` 模擬玩家視角的純邏輯解題過程。
- 每步僅使用確定安全的格子進行虛擬翻開與 Flood Fill 連鎖展開。
- 若整盤皆能被純邏輯完整解開，則判定棋盤合格；若遇到必須猜測局面，則重新受約束生成。
- 設定時間防護與最大嘗試次數 (`maxAttempts = 30`)，防止無休止計算。

### 3. 事務性棋局修復引擎 (`BoardRepairEngine`)
- **足跡等價對調原理 (Footprint-Equivalence Swap)**：
  - 定義未知格的覆蓋足跡：$\text{Footprint}(v) = N(v) \cap \text{Revealed}$。
  - 當兩個未知格擁有完全相同的覆蓋足跡時，對調其地雷狀態，所有已揭露格子的相鄰雷數變化量均為 $(-1) + (+1) = 0$！
  - 數學上 100% 保證：**所有已翻開的數字維持絕對不變、總地雷數維持絕對不變、絕不在已翻開格放置地雷**。
- **嚴格事務性 (Transactional ACID-like)**：先在複製棋盤中進行模擬，再使用 Solver 檢驗修復後是否消除猜測；若驗證失敗立即自動 Rollback 回原盤面，確保零副作用。

### 4. 即時動態防猜 (`dynamicAntiGuessIfEnabled`)
- 玩家在 No-Guess Mode 下每次點擊翻開格子後，引擎立即運行快速邏輯檢測。
- 若發現當前盤面陷入 `GUESS_REQUIRED` 且存在未翻開格，自動觸發背景微調修復，解除死局。
- 若修復成功，即時在介面給出非侵入式提示：「✨ 動態防猜已調整雷區，當前盤面已保證可依純邏輯推導解開！」

### 5. AI 修復助理與可視化預覽介面 (`BoardRepairSheet`)
- 整合 Ollama 與純 Swift 引擎產生修復建議。
- 提供前後對比的「修復預覽互動卡片」：清楚標示受影響的格子座標與雷區轉移方向。
- 採用「玩家確認後套用」機制，不強加於玩家，並提供清晰說明。

### 6. 公平性追蹤與排行榜隔離 (`GameFairnessRecord`)
- 精準追蹤每局遊戲的輔助紀錄：`repairedCount`、`aiSuggestionsUsed`、`autoSolvedStepCount`、`hintsUsed`。
- 任何修復或 AI 自動排雷均會將 `isPureClassicValid` 標記為 `false`。
- 純粹經典排行榜嚴格隔離，杜絕任何作弊干擾，保障競技公平性。

### 7. 推理歷程可視化 (`ReasoningHistorySheet`)
- `ReasoningHistoryManager` 完整記錄每一步推理的邏輯規則、受影響座標、機率分佈與信心分數。
- 支援查看歷史推理脈絡（單格確定、集合相減、CSP 深度回溯等）。

### 8. XCTest 驗證成果
- **測試總數增加至 31 項**，100% 通過（包含 8 項 Phase 4.5 專屬測試）：
  - `testNoGuessBoardGeneratorProducesSolvableBoard`
  - `testNoGuessGeneratorRejectsGuessingBoards`
  - `testBoardRepairPreservesRevealedNumbersAndTotalMines`
  - `testBoardRepairRollbackOnFailure`
  - `testDynamicAntiGuessInNoGuessMode`
  - `testAutoSolveNeverRevealsMinesAndStopsOnGuess`
  - `testFairnessRecordSeparation`
  - `testAISuggestionValidationRejectsIllegalMove`
