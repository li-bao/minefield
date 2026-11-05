# Minefield 完整自動化測試與驗證報告 (Phase 5)

本報告記錄 **Minefield** 專案全體單元測試、演算法驗證、資訊隱藏安全檢測及終端使用者煙霧測試（Smoke Test）之完整執行成果。

---

## 1. 測試概況總覽

| 項目 | 統計數據 |
| :--- | :--- |
| **測試框架** | Apple XCTest Framework (透過 Swift Package Manager) |
| **目標架構** | Apple Silicon ARM64 (`arm64-apple-macos14.0`) |
| **測試套件數** | 4 個測試套件 (Test Suites) |
| **總測試案例數** | **43 案例** |
| **成功率** | **100% (43 通過 / 0 失敗 / 0 跳過)** |
| **測試執行總時間** | 約 0.045 秒 (並行測試加速) |
| **二進位狀態** | Release 零警告、無 Force Unwraps (`!`)、符合 Swift 6 Sendable 嚴格要求 |

---

## 2. 測試套件詳細拆解

### 2.1 核心遊戲規則與棋盤引擎測試 (`MinefieldTests` - 14 個測試案例)

驗證標準掃雷邏輯、邊界檢查、首步安全與遊戲勝利/失敗狀態轉換：

| 測試案例 | 驗證重點與斷言邏輯 | 結果 |
| :--- | :--- | :---: |
| `testGameDifficultyConfigurations` | 驗證 Beginner (9x9, 10 雷)、Intermediate (16x16, 40 雷)、Expert (30x16, 99 雷) 尺寸與雷數配置精確度。 | PASS |
| `testCustomBoardValidationRules` | 驗證寬度 5~40、高度 5~30、地雷數量必須小於 `(rows*cols - 9)` 之動態邊界檢驗。 | PASS |
| `testFirstClick3x3SafeZone` | 驗證首次點擊中央區域時，該座標及其周圍 3x3 共 9 格必然無地雷。 | PASS |
| `testCornerFirstClickSafeZone` | 驗證棋盤角落點擊時之邊界截斷安全區（角落 2x2 共 4 格必然無雷且總雷數維持不變）。 | PASS |
| `testFlaggingAndProtection` | 驗證插旗、取消插旗操作，以及插旗格子對點擊翻開的防護拒絕行為。 | PASS |
| `testFloodFillDoesNotRevealFlaggedCells` | 驗證空地展開（Flood Fill）在擴散時絕不自動揭露玩家已插旗的格子。 | PASS |
| `testChordingOperation` | 驗證點擊已揭開數字雙擊/Chording 功能（周圍插旗數相符時自動翻開其餘鄰格）。 | PASS |
| `testClassicModeDefeat` | 驗證經典模式下踩雷立即判定失敗、停止計時並揭露全部真實地雷陣。 | PASS |
| `testPenaltyModeOperation` | 驗證時間懲罰模式下踩雷不會立即失敗，而是扣除懲罰秒數並允許繼續遊戲。 | PASS |
| `testVictoryConditionWithoutFullFlagging` | 驗證掃雷國際賽事標準勝利判定：只要揭開所有安全格即可獲勝，無需插滿全部旗標。 | PASS |
| `testTotalMineCountAcrossDifficulties` | 驗證各難度初始化後內部真實地雷數量精確等於設定值。 | PASS |
| `testNeighboringMinesCalculationAccuracy` | 驗證相鄰地雷計算法則，確保每個揭開格子的數字與鄰居地雷數完全一致。 | PASS |
| `testPublicBoardInformationHiding` | **核心安全測試**：驗證 `PublicBoard` 介面絕對無法讀取內部尚未揭露的真實地雷分佈（未揭開格讀取 `hasMine` 必回傳 `false` 或隱蔽）。 | PASS |
| `testSeedReproducibilityAndRestart` | 驗證特定隨機種子（Seed）在相同難度下可 100% 重現完全一致的地雷與棋盤分佈。 | PASS |

---

### 2.2 求解器與 Ollama AI 整合測試 (`Phase4SolverAndAITests` - 9 個測試案例)

驗證獨立 CSP 求解器、機率分析、子集推理與 Ollama AI 防作弊安全邊界：

| 測試案例 | 驗證重點與斷言邏輯 | 結果 |
| :--- | :--- | :---: |
| `testBuiltinSolverWorksIndependently` | 驗證內建數學求解器可完全獨立運作，無需 Ollama 服務或網路連線。 | PASS |
| `testInformationHidingGuaranteesNoCheating` | 驗證求解器僅傳入 `PublicBoard`，AI 模組絕對無法作弊或透視隱藏地雷。 | PASS |
| `testGuaranteedSafeCellDiscovery` | 驗證透過周邊約束方程精準推算出 100% 絕對安全格。 | PASS |
| `testGuaranteedMineDiscovery` | 驗證透過數字約束精準識別 100% 必然地雷並正確建議插旗。 | PASS |
| `testSubsetDeductionInference` | 驗證進階集合包含推理（如經典 1-2-1、1-2-2-1 模式與約束相減法則）。 | PASS |
| `testRecognizeGuessRequiredAndProbabilityAccuracy` | 驗證當邏輯確定步數耗盡時，求解器能正確標記 `guessRequired = true` 並計算各未知格的精確踩雷機率。 | PASS |
| `testSearchResourceLimitReportsIncomplete` | 驗證在超大未知邊界時，DFS / Backtracking 在達到資源上限時優雅終止並標記結果狀態。 | PASS |
| `testAISafetyValidationRejectsIllegalSuggestions` | 驗證安全驗證器（Safety Validator）能攔截並拒絕 AI 提出的違規建議（如建議點擊已翻開格、已插旗格或高風險格）。 | PASS |
| `testAICorruptedJSONHandling` | 驗證當外部 Ollama 模型回傳非預期格式、毀損 JSON 或幻覺文字時，系統能安全降級至內建求解器，絕不崩潰。 | PASS |

---

### 2.3 動態智慧棋局與事務修復測試 (`Phase4_5DynamicAIBoardTests` - 8 個測試案例)

驗證 No-Guess 棋局生成、動態防猜、棋局事務性修復與公平性紀錄分離：

| 測試案例 | 驗證重點與斷言邏輯 | 結果 |
| :--- | :--- | :---: |
| `testNoGuessBoardGeneratorProducesSolvableBoard` | 驗證生成器產生的 No-Guess 棋盤能從首步開始完全透過邏輯無猜解完。 | PASS |
| `testNoGuessGeneratorRejectsGuessingBoards` | 驗證生成器在模擬解題遇到需盲猜的情況時，主動捨棄並重新生成。 | PASS |
| `testDynamicAntiGuessInNoGuessMode` | 驗證若玩家進入死局，動態防猜系統能平滑重配未知區地雷，創造出邏輯突破口。 | PASS |
| `testBoardRepairPreservesRevealedNumbersAndTotalMines` | 驗證修復引擎在重新配置地雷時，**100% 嚴格保持目前所有已揭露的數字不變**，且總雷數精確不變。 | PASS |
| `testBoardRepairRollbackOnFailure` | 驗證修復演算法具備完整交易性（Transaction），修復無解時保證復原（Rollback）原始棋盤狀態。 | PASS |
| `testAutoSolveNeverRevealsMinesAndStopsOnGuess` | 驗證自動排雷功能僅點擊 100% 安全格，遇猜測局面時立即暫停提示玩家。 | PASS |
| `testFairnessRecordSeparation` | 驗證啟用 AI 修復或動態輔助之局數，與純手動 Classic 模式之排行榜、成就與統計數據完全隔離。 | PASS |
| `testAISuggestionValidationRejectsIllegalMove` | 驗證 AI 提出的動態修復建議若破壞現有已翻開數字限制，驗證器立即予以駁回。 | PASS |

---

### 2.4 終極擴充系統與資料持久化測試 (`Phase4_75UltimateFeatureTests` - 12 個測試案例)

驗證 Phase 4.75 新增之全方位系統（模擬、回放、成就、歷史、撤銷重做與沙盒）：

| 測試案例 | 驗證重點與斷言邏輯 | 結果 |
| :--- | :--- | :---: |
| `testWhatIfSimulationContradiction` | 驗證 What-If 假設模擬引擎在假設某格為雷或安全時，能藉由前向傳播檢測矛盾並標記推論結果。 | PASS |
| `testDifficultyRatingEngineRange` | 驗證難度評級引擎（3BV、前線複雜度、開局島嶼數）之計算指標與評分落在 1.0~10.0 合理區間。 | PASS |
| `testProbabilityCalculatorAndHeatmap` | 驗證全域未知格之機率熱圖（Heatmap）產生無誤，邊界各格機率總和符合殘餘地雷守恆。 | PASS |
| `testUndoRedoLifecycle` | 驗證 Undo / Redo 堆疊生命週期，在非天梯模式下支援多步驟安全復原與狀態重現。 | PASS |
| `testDailyChallengeDeterministicSeed` | 驗證每日挑戰根據公曆日期（YYYYMMDD）產生唯一的確定性種子，當日所有玩家棋局一致。 | PASS |
| `testReplayRecordingAndPlayback` | 驗證操作回放錄製引擎能記錄每步毫秒級時間戳與操作類型，並能一步步完整回放。 | PASS |
| `testAchievementManagerUnlocks` | 驗證成就解鎖條件判定（首勝、高難度通關、無猜模式達標等）與本機持久化狀態。 | PASS |
| `testStatisticsServiceSegregation` | 驗證統計服務能依模式（Classic、No-Guess、AI-Assisted）嚴格分開計算勝率、連勝與最佳時間。 | PASS |
| `testSaveGameAtomicWriteAndCorruptedRecovery` | 驗證遊戲中斷儲存採用原子寫入（Atomic Write），並在檔案損毀時能優雅捕捉錯誤並安全重置，絕不崩潰。 | PASS |
| `testThemeManagerPresets` | 驗證 5 套高對比配色方案（經典石墨、賽博龐克、復古紙質、極簡深邃、高對比無障礙）色彩規格。 | PASS |
| `testSandboxSharingCodeEncodeDecode` | 驗證沙盒棋盤編輯器之 Base64 棋盤編碼字串之雙向編解碼無損還原。 | PASS |
| `testAIRescueSafetyAndFairness` | 驗證 AI 救援模式（踩雷時自動介入修復）正確消耗救援額度，並如實標記局勢輔助標籤。 | PASS |

---

## 3. 端對端煙霧測試 (End-to-End Smoke Test)

為確保交付之 DMG 安裝映像檔在真實 macOS 終端使用者環境下能順暢運作，執行了完整端對端掛載與執行測試：

1. **DMG 掛載檢驗**：
   - 執行 `hdiutil attach dist/Minefield-AppleSilicon.dmg -mountpoint /tmp/minefield_mount`
   - 驗證掛載點正常生成，唯讀保護生效。
   - 包含根目錄內容：`Minefield.app` (二進位與資源完整) 以及指向 `/Applications` 之軟連結。
2. **應用程式複製與完整性檢驗**：
   - 複製至 `/tmp/Minefield_SmokeTest.app`。
   - 執行 `codesign --verify --deep --strict --verbose=4`，驗證簽名結果為「valid on disk, satisfies Designated Requirement」。
   - 執行 `plutil -lint` 驗證 `Info.plist` 合法性。
   - 檢驗 `Minefield.icns` 與 `AppIcon.icns` 完整就位。
3. **執行期啟動與生命週期檢驗**：
   - 執行 `/tmp/Minefield_SmokeTest.app/Contents/MacOS/Minefield`。
   - 進程成功啟動（PID: 12497），主執行緒事件迴圈與 SwiftUI 介面正常初始化。
   - 發送 `SIGTERM` 信號，程序優雅釋放資源並順暢退出，無崩潰或 Memory Leak 警告。
4. **清理檢驗**：
   - 成功卸載 DMG（`hdiutil detach`），清理暫存檔案。

---

## 4. 驗收結論

Minefield 專案在 Apple Silicon (ARM64) macOS 原生環境下，通過全部 43 項單元測試、演算法約束驗證、資訊安全驗證與煙霧測試，具備正式 Release 交付資格。
