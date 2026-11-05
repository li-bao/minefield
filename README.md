Minefield
Minefield 是一款以 Apple Silicon 為主要目標、使用 Swift 與 SwiftUI 開發的原生 macOS 掃雷遊戲。除了傳統掃雷玩法，專案也朝向整合本機 Ollama AI、邏輯求解、機率分析與無猜棋局等進階功能發展。
開發中（Work in Progress）：Minefield 尚未完成最終驗收與 DMG 發行。README 中標示為規劃中的功能，不代表目前版本已經實作完成；請以實際程式碼、測試結果及 Releases 頁面為準。

目標與特色
- 原生 macOS 體驗：以 Swift / SwiftUI 建立 Apple Silicon 原生桌面應用程式。
- 經典掃雷玩法：單擊翻開、長按插旗、右鍵插旗、連鎖展開與勝利判定。
- 多種難度：簡單、中等、困難，以及可自訂棋盤寬度、高度與地雷數量。
- 智慧邏輯求解：以可驗證的規則推理找出必然安全格與必然地雷。
- 機率分析：分析未知格的地雷風險；計算資源不足或結果不完整時，應明確標示。
- Ollama 本機 AI：規劃透過本機 Ollama 分析可見棋盤、解釋推理及提供候選建議。
- 提示與時間懲罰：提供分級提示、踩雷懲罰及可調整的遊戲規則。
- 無猜棋局與 AI 救援：規劃支援無猜棋局驗證、AI 救援及獨立沙盒模擬。
開發進度
模組	目前狀態
掃雷遊戲核心與基本難度	已進入開發；以目前專案實際程式碼為準
SwiftUI macOS 介面	已進入開發；仍需完整驗收
內建 Solver 與 Ollama 整合	已進入 Phase 4；仍需測試與驗證
無猜棋局生成與動態防猜	後續擴充項目（Phase 4.5）
AI 救援、提示及棋局管理擴充	後續擴充項目（Phase 4.5 / 4.75）
回放、Undo / Redo、自動存檔、成就與統計	後續擴充項目（Phase 4.75）
最終 ARM64 Release 與 DMG	尚未完成（Phase 5）


技術規劃
項目	技術
語言	Swift
使用者介面	SwiftUI / macOS 原生 API
套件與建置	Swift Package Manager（依專案實際設定）
測試	XCTest
本機 AI	Ollama REST API（選用）
發行格式	macOS .app 與 .dmg（Phase 5）
主要架構	Apple Silicon / arm64


系統需求
- Apple Silicon Mac（M 系列）。
- macOS 14 或更新版本（實際最低版本以專案設定為準）。
- Xcode Command Line Tools 或完整 Xcode，需包含相容的 Swift 編譯器及 macOS SDK。
- Ollama：只有使用本機 AI 功能時才需要；一般掃雷與內建邏輯求解不應依賴 Ollama。
開發環境與建置
1. 取得專案
git clone https://github.com/<YOUR_GITHUB_USERNAME>/Minefield.git
cd Minefield
將 <YOUR_GITHUB_USERNAME> 換成你的 GitHub 帳號名稱。如果你的 Repository 使用其他名稱，也請同步修改網址。
2. 檢查 Swift 工具鏈
swift --version
xcode-select -p
如果系統尚未安裝 Command Line Tools，請依照 macOS 顯示的 Apple 官方安裝流程完成安裝。
3. 編譯與測試
若專案根目錄包含有效的 Package.swift：
swift build -c release
swift test
若專案已提供建置腳本，請優先依照腳本及 docs/ 中的專案說明執行。實際執行方式以目前 Package.swift 的 executable product、Xcode 專案設定及 Scripts/ 內的腳本為準。
Ollama 本機 AI
Ollama 是選用功能，不是遊戲基本玩法的必要依賴。若要使用 AI 分析：
1. 在 Mac 上安裝並啟動 Ollama。
2. 確認本機服務可用，預設網址為 http://localhost:11434。
3. 在 Minefield 的 AI 設定中測試連線並選擇已安裝的模型。
4. 只有在使用者啟動分析時，才將目前可見的棋盤資訊交給本機模型。
可用以下指令檢查 Ollama 是否能回應：
curl http://localhost:11434/api/tags
AI 的文字建議不等於數學證明。必然安全格、必然地雷及地雷機率應由遊戲內可測試的 Solver / Probability Engine 判定；模型不能讀取隱藏地雷配置，也不能未經驗證直接修改遊戲狀態。
遊戲設計原則
1. 正確性優先：遊戲規則與數學求解正確性優先於 AI 效果及視覺特效。
2. 本機優先：核心遊戲與內建 Solver 應可在沒有 Ollama 的情況下運作。
3. 可驗證的 AI：AI 只提供解釋及候選建議；所有遊戲操作都由 GameEngine 驗證。
4. 尊重已知資訊：不可將已揭露數字或玩家可見資訊偷偷改掉，藉此假裝消除猜測。
5. 狀態透明：若求解器因搜尋限制而無法完成分析，必須顯示結果不完整，不得將近似結果標成確定答案。
關於無猜與 AI 救援
「存在一條無猜解題路徑」不代表玩家任意選擇都不會遇到猜測。若玩家進入沒有必然安全格的局面，單純移動未揭露地雷、同時保留所有已揭露數字與公開限制，並不能改變這些限制所代表的解答集合。因此，Minefield 將無猜棋局驗證、獨立沙盒重建，以及明確標示的 AI 救援揭露視為不同功能，不會把其中一種冒充成另一種。
專案結構
以下為預計採用的模組方向；實際資料夾名稱可能隨開發調整：
Minefield/
├── Package.swift
├── Sources/
│   └── Minefield/
│       ├── App/
│       ├── Models/
│       ├── GameEngine/
│       ├── Solver/
│       ├── AI/
│       ├── Views/
│       ├── Components/
│       ├── Services/
│       ├── Settings/
│       └── Utilities/
├── Tests/
│   └── MinefieldTests/
├── Resources/
├── Scripts/
├── docs/
└── README.md
隱私與安全
- 不要將 Ollama API 以外的密鑰、密碼、私人 Token 或個人資料提交到 GitHub。
- 不要提交 .env、憑證檔、私人設定或本機日誌。
- 使用 Ollama 時，預設應連接本機服務；若改用其他主機，應明確提醒使用者資料可能離開本機。
- 不應將隱藏地雷配置傳給 AI 模型。
回報問題
回報問題時，請盡量附上：
- macOS 版本與 Mac 型號／晶片架構。
- Minefield 版本或 Git commit。
- 重現問題的操作步驟。
- 相關錯誤訊息及測試結果。
請勿附上密碼、Token 或其他私人資訊。
授權條款
目前尚未在此 Repository 指定開源授權。除非日後加入 LICENSE 檔案並明確說明授權條款，否則請勿假設本專案可以自由複製、修改或散布。
Minefield · Native macOS Minesweeper · Built for Apple Silicon
