import Foundation

/// 純 Swift 原生掃雷遊戲引擎
/// 完全與 UI 解耦，支援獨立測試與無狀態演算法整合
public final class GameEngine: GameEngineProtocol, ObservableObject {
    // MARK: - 公開遊戲狀態
    @Published public private(set) var difficulty: GameDifficulty
    @Published public private(set) var mode: GameMode
    @Published public private(set) var state: GameState
    @Published public private(set) var currentSeed: UInt64
    @Published public private(set) var explodedMineCount: Int
    @Published public var penaltySecondsPerMine: TimeInterval

    /// 內部完整棋盤 (包含地雷機密位置)
    @Published public private(set) var internalBoard: Board

    // MARK: - 計時相關
    public private(set) var startDate: Date?
    public private(set) var endDate: Date?

    /// 允許測試或外部注入固定計時
    public var simulatedElapsedTime: TimeInterval?

    // MARK: - 棋局公平性與詳細操作統計
    @Published public private(set) var fairnessRecord: GameFairnessRecord

    // MARK: - 事件回呼 (可供 UI 綁定動畫與音效)
    public var onExplosion: ((Int, Int) -> Void)?
    public var onVictory: (() -> Void)?
    public var onDefeat: (() -> Void)?
    public var onBoardRepaired: ((BoardRepairResult) -> Void)?

    // MARK: - 初始化
    public init(
        difficulty: GameDifficulty = .intermediate,
        mode: GameMode = .penalty,
        penaltySecondsPerMine: TimeInterval = 30.0,
        seed: UInt64? = nil
    ) {
        self.difficulty = difficulty
        self.mode = mode
        self.penaltySecondsPerMine = penaltySecondsPerMine
        self.state = .ready
        self.explodedMineCount = 0
        let effectiveSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        self.currentSeed = effectiveSeed
        self.fairnessRecord = GameFairnessRecord(seed: effectiveSeed)

        let config = difficulty.configuration
        self.internalBoard = Board(rows: config.rows, columns: config.columns, totalMines: config.mines)
    }

    // MARK: - 唯讀統計屬性

    /// 剩餘旗幟計數 (總地雷數 - 目前已插旗數)
    public var remainingMinesToFlag: Int {
        internalBoard.totalMines - internalBoard.flaggedCount
    }

    /// 純遊玩經過時間 (秒)
    public var pureElapsedTime: TimeInterval {
        if let simulated = simulatedElapsedTime {
            return simulated
        }
        guard let start = startDate else {
            return 0.0
        }
        if state == .won || state == .lost {
            return (endDate ?? start).timeIntervalSince(start)
        }
        return Date().timeIntervalSince(start)
    }

    /// 加總懲罰後的總成績時間 (秒)
    public var totalTimeWithPenalties: TimeInterval {
        pureElapsedTime + (Double(explodedMineCount) * penaltySecondsPerMine)
    }

    // MARK: - 安全公開視圖 (供 UI、AI、Solver 讀取，絕不外洩未揭開的地雷)

    public func publicBoard() -> [[PublicCell]] {
        internalBoard.toPublicGrid(isGameOver: (state == .won || state == .lost))
    }

    public func publicCell(atRow row: Int, column: Int) -> PublicCell? {
        guard internalBoard.isValidCoordinate(row: row, column: column) else {
            return nil
        }
        return PublicCell.from(
            cell: internalBoard[row, column],
            isGameOver: (state == .won || state == .lost)
        )
    }

    // MARK: - 核心操作

    /// 翻開指定格子 (左鍵點擊)
    @discardableResult
    public func revealCell(atRow row: Int, column: Int) -> Bool {
        guard internalBoard.isValidCoordinate(row: row, column: column) else {
            return false
        }

        // 僅允許在 ready 或 inProgress 狀態操作
        guard state == .ready || state == .inProgress else {
            return false
        }

        let cell = internalBoard[row, column]

        // 禁止翻開已插旗或已翻開的格子
        guard cell.state == .hidden else {
            return false
        }

        objectWillChange.send()

        UndoRedoManager.shared.recordSnapshot(captureSnapshot(action: "翻開 (\(row), \(column))"))

        // 第一步安全機制：首步點擊時才進行地雷佈局
        if state == .ready {
            deployMinesWithSafeZone(firstRow: row, firstCol: column)
            state = .inProgress
            startDate = Date()
        }

        let success = executeReveal(row: row, column: column)
        if success {
            ReplayEngine.shared.recordStep(
                actionType: .reveal,
                coordinate: GridCoordinate(row, column),
                description: "翻開 (\(row), \(column))",
                board: internalBoard,
                state: state,
                explodedCount: explodedMineCount
            )
        }
        return success
    }

    /// 插旗或取消插旗 (右鍵點擊或長按操作)
    @discardableResult
    public func toggleFlag(atRow row: Int, column: Int) -> Bool {
        guard internalBoard.isValidCoordinate(row: row, column: column) else {
            return false
        }
        guard state == .ready || state == .inProgress else {
            return false
        }

        let current = internalBoard[row, column]
        guard current.state == .hidden || current.state == .flagged else {
            return false
        }

        UndoRedoManager.shared.recordSnapshot(captureSnapshot(action: current.state == .hidden ? "插旗 (\(row), \(column))" : "取消插旗 (\(row), \(column))"))

        objectWillChange.send()

        switch current.state {
        case .hidden:
            internalBoard[row, column].state = .flagged
            ReplayEngine.shared.recordStep(
                actionType: .flag,
                coordinate: GridCoordinate(row, column),
                description: "插旗 (\(row), \(column))",
                board: internalBoard,
                state: state,
                explodedCount: explodedMineCount
            )
            return true
        case .flagged:
            internalBoard[row, column].state = .hidden
            ReplayEngine.shared.recordStep(
                actionType: .unflag,
                coordinate: GridCoordinate(row, column),
                description: "取消插旗 (\(row), \(column))",
                board: internalBoard,
                state: state,
                explodedCount: explodedMineCount
            )
            return true
        case .revealed, .exploded:
            return false
        }
    }

    /// 快捷翻開周圍未插旗格子 (Chording: 點擊已翻開的數字格)
    @discardableResult
    public func chordReveal(atRow row: Int, column: Int) -> Bool {
        guard internalBoard.isValidCoordinate(row: row, column: column) else {
            return false
        }
        guard state == .inProgress else {
            return false
        }

        let cell = internalBoard[row, column]
        // 必須為已翻開且相鄰地雷大於 0 的格子
        guard cell.state == .revealed && cell.neighboringMines > 0 else {
            return false
        }

        // 檢查相鄰已插旗數是否等於該格數字
        let flaggedCount = internalBoard.flaggedNeighborsCount(ofRow: row, column: column)
        guard flaggedCount == cell.neighboringMines else {
            return false
        }

        objectWillChange.send()

        UndoRedoManager.shared.recordSnapshot(captureSnapshot(action: "和弦翻開 (\(row), \(column))"))

        // 翻開周圍所有未插旗且未翻開的相鄰格子
        var anyRevealed = false
        let neighbors = internalBoard.neighborCoordinates(ofRow: row, column: column)
        for (nr, nc) in neighbors {
            if internalBoard[nr, nc].state == .hidden {
                let success = executeReveal(row: nr, column: nc)
                if success { anyRevealed = true }
                // 經典模式下若已失敗，立即中止後續連鎖
                if state == .lost {
                    break
                }
            }
        }

        if anyRevealed {
            ReplayEngine.shared.recordStep(
                actionType: .chord,
                coordinate: GridCoordinate(row, column),
                description: "和弦翻開 (\(row), \(column)) 周圍安全格",
                board: internalBoard,
                state: state,
                explodedCount: explodedMineCount
            )
        }
        return anyRevealed
    }

    // MARK: - 重新開始與模式切換

    /// 重新開始當前棋盤 (保留相同 Seed 與設定)
    public func restartCurrentGame() {
        let config = difficulty.configuration
        self.internalBoard = Board(rows: config.rows, columns: config.columns, totalMines: config.mines)
        self.state = .ready
        self.explodedMineCount = 0
        self.startDate = nil
        self.endDate = nil
        self.fairnessRecord.reset(seed: currentSeed)
        UndoRedoManager.shared.clear()
        ReplayEngine.shared.startRecording(
            initialBoard: self.internalBoard,
            difficulty: self.difficulty,
            mode: self.mode,
            seed: self.currentSeed
        )
    }

    /// 以指定難度開始新局
    public func startNewGame(
        difficulty: GameDifficulty,
        mode: GameMode = .penalty,
        seed: UInt64? = nil
    ) {
        self.difficulty = difficulty
        self.mode = mode
        self.currentSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        self.restartCurrentGame()
    }

    /// 以自訂難度開始新局
    public func startCustomGame(
        config: CustomBoardConfig,
        mode: GameMode = .penalty,
        seed: UInt64? = nil
    ) {
        let validatedConfig: CustomBoardConfig
        switch config.validate() {
        case .success(let val):
            validatedConfig = val
        case .failure:
            // 自動修正至合法邊界範圍
            let safeW = min(max(config.width, CustomBoardConfig.minWidth), CustomBoardConfig.maxWidth)
            let safeH = min(max(config.height, CustomBoardConfig.minHeight), CustomBoardConfig.maxHeight)
            let maxM = CustomBoardConfig.maxMines(forWidth: safeW, height: safeH)
            let safeM = min(max(config.mines, CustomBoardConfig.minMines), maxM)
            validatedConfig = CustomBoardConfig(width: safeW, height: safeH, mines: safeM)
        }

        self.difficulty = .custom(validatedConfig)
        self.mode = mode
        self.currentSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        self.restartCurrentGame()
    }

    // MARK: - 私有演算法實作

    /// 部署地雷並建立 3×3 安全保護區
    private func deployMinesWithSafeZone(firstRow: Int, firstCol: Int) {
        let rows = internalBoard.rows
        let cols = internalBoard.columns
        let totalMines = internalBoard.totalMines

        // 3×3 安全區座標集合
        var safeCoords = Set<String>()
        for dr in -1...1 {
            for dc in -1...1 {
                let r = firstRow + dr
                let c = firstCol + dc
                if internalBoard.isValidCoordinate(row: r, column: c) {
                    safeCoords.insert("\(r),\(c)")
                }
            }
        }

        // 收集所有允許埋雷的候選座標
        var candidates: [(row: Int, column: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if !safeCoords.contains("\(r),\(c)") {
                    candidates.append((row: r, column: c))
                }
            }
        }

        // 極限防禦保護：若地雷數多於候選區，則縮小安全區至首發單格
        if candidates.count < totalMines {
            candidates.removeAll()
            for r in 0..<rows {
                for c in 0..<cols {
                    if !(r == firstRow && c == firstCol) {
                        candidates.append((row: r, column: c))
                    }
                }
            }
        }

        // 若為無猜防猜模式，優先尋找天然無猜解題路徑之種子
        if mode == .noGuess {
            var trySeed = currentSeed
            for _ in 0..<35 {
                var testBoard = internalBoard
                deployMinesFromCandidates(board: &testBoard, candidates: candidates, totalMines: totalMines, seed: trySeed)
                if NoGuessBoardGenerator.shared.isNaturallySolvableWithoutGuess(board: testBoard, firstClick: (firstRow, firstCol)) {
                    self.internalBoard = testBoard
                    self.currentSeed = trySeed
                    return
                }
                trySeed = trySeed &+ 0x9e3779b97f4a7c15
            }
        }

        // 標準部署
        deployMinesFromCandidates(board: &internalBoard, candidates: candidates, totalMines: totalMines, seed: currentSeed)
    }

    private func deployMinesFromCandidates(board: inout Board, candidates: [(row: Int, column: Int)], totalMines: Int, seed: UInt64) {
        var mutableCandidates = candidates
        var rng = SeededRandom(seed: seed)
        mutableCandidates.shuffle(using: &rng)

        let mineCount = min(totalMines, mutableCandidates.count)
        for i in 0..<mineCount {
            let pos = mutableCandidates[i]
            board[pos.row, pos.column].hasMine = true
        }

        // 計算全盤各格周圍地雷數
        for r in 0..<board.rows {
            for c in 0..<board.columns {
                if board[r, c].hasMine {
                    board[r, c].neighboringMines = 0
                } else {
                    let count = board.neighborCoordinates(ofRow: r, column: c).reduce(0) { sum, coord in
                        board[coord.row, coord.column].hasMine ? sum + 1 : sum
                    }
                    board[r, c].neighboringMines = count
                }
            }
        }
    }

    /// 執行單一格子的翻開與連鎖邏輯
    private func executeReveal(row: Int, column: Int) -> Bool {
        guard internalBoard.isValidCoordinate(row: row, column: column) else {
            return false
        }

        let target = internalBoard[row, column]
        guard target.state == .hidden else {
            return false
        }

        if target.hasMine {
            // 踩中地雷！
            if mode == .classic {
                // 經典模式：立即輸掉遊戲
                internalBoard[row, column].state = .exploded
                state = .lost
                endDate = Date()
                onExplosion?(row, column)
                onDefeat?()
                revealAllMinesOnLoss()
                return true
            } else {
                // 懲罰模式：累計懲罰，格子標記爆炸，遊戲繼續
                internalBoard[row, column].state = .exploded
                explodedMineCount += 1
                onExplosion?(row, column)
                checkVictoryCondition()
                return true
            }
        } else {
            // 翻開安全格子
            internalBoard[row, column].state = .revealed

            // 若為 0 數字格，執行廣度優先 Flood Fill 自動展開
            if target.neighboringMines == 0 {
                performFloodFill(startRow: row, startCol: column)
            }

            checkVictoryCondition()

            // 動態防猜機制 (No-Guess Mode)：每次翻開後若陷入猜測，立即自動執行最小修復
            if mode == .noGuess && state == .inProgress {
                handleDynamicAntiGuess()
            }

            return true
        }
    }

    /// 廣度優先搜尋 (BFS) 洪水填充展開演算法
    /// 嚴格確保不會覆蓋插旗格子 (Flagged)
    private func performFloodFill(startRow: Int, startCol: Int) {
        var queue: [(row: Int, column: Int)] = [(startRow, startCol)]
        var visited = Set<String>()
        visited.insert("\(startRow),\(startCol)")

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = internalBoard.neighborCoordinates(ofRow: current.row, column: current.column)

            for (nr, nc) in neighbors {
                let key = "\(nr),\(nc)"
                guard !visited.contains(key) else { continue }
                visited.insert(key)

                let nCell = internalBoard[nr, nc]

                // 絕不覆蓋插旗格子，也不翻開地雷格
                if nCell.state == .hidden && !nCell.hasMine {
                    internalBoard[nr, nc].state = .revealed

                    // 若鄰居亦為 0，繼續加入佇列向外擴展
                    if nCell.neighboringMines == 0 {
                        queue.append((nr, nc))
                    }
                }
            }
        }
    }

    /// 勝利檢測：當所有非地雷格子皆被翻開時判定獲勝
    private func checkVictoryCondition() {
        guard state == .inProgress else { return }

        // 在懲罰模式或經典模式下，勝利條件皆為安全格全數揭開
        if internalBoard.revealedCount == internalBoard.totalSafeCells {
            state = .won
            endDate = Date()

            // 獲勝時將剩餘未被引爆的地雷自動補旗
            for r in 0..<internalBoard.rows {
                for c in 0..<internalBoard.columns {
                    if internalBoard[r, c].hasMine && internalBoard[r, c].state == .hidden {
                        internalBoard[r, c].state = .flagged
                    }
                }
            }

            onVictory?()
        }
    }

    /// 經典模式失敗時揭露其餘隱藏地雷
    private func revealAllMinesOnLoss() {
        for r in 0..<internalBoard.rows {
            for c in 0..<internalBoard.columns {
                if internalBoard[r, c].hasMine && internalBoard[r, c].state == .hidden {
                    internalBoard[r, c].state = .revealed
                }
            }
        }
    }

    // MARK: - 動態防猜與自動排雷擴充

    /// 動態防猜機制 (No-Guess Mode)
    private func handleDynamicAntiGuess() {
        let solverResult = SmartSolver.shared.analyze(
            grid: internalBoard.toPublicGrid(),
            totalMines: internalBoard.totalMines,
            flaggedCount: internalBoard.flaggedCount
        )

        if solverResult.status == .guessRequired {
            let repairResult = BoardRepairEngine.shared.attemptRepair(
                board: internalBoard,
                solverResult: solverResult
            )

            if repairResult.success, let repaired = repairResult.repairedBoard {
                self.internalBoard = repaired
                self.fairnessRecord.repairCount += 1
                self.fairnessRecord.movedMinesCount += repairResult.movedMinesCount

                ReasoningHistoryManager.shared.addStep(
                    ReasoningStep(
                        method: "動態防猜修復",
                        resultType: "棋盤已微調",
                        wasRepaired: true,
                        detail: "偵測到局盤可能進入猜測，系統已在保證已揭露數字不變前提下微調 \(repairResult.movedMinesCount) 顆隱藏雷，產生 \(repairResult.newSafeCells.count) 個必然安全步。"
                    )
                )

                onBoardRepaired?(repairResult)
            }
        }
    }

    /// 執行一步或連鎖自動排雷 (Auto Solve)
    @discardableResult
    public func performAutoSolveStep() -> (revealed: [GridCoordinate], flagged: [GridCoordinate], isGuessRequired: Bool) {
        guard state == .inProgress || state == .ready else {
            return ([], [], false)
        }

        let solverResult = SmartSolver.shared.analyze(
            grid: internalBoard.toPublicGrid(),
            totalMines: internalBoard.totalMines,
            flaggedCount: internalBoard.flaggedCount
        )

        var newlyFlagged: [GridCoordinate] = []
        var newlyRevealed: [GridCoordinate] = []

        // 先標記必然地雷
        for m in solverResult.sureMineCells {
            if internalBoard[m.row, m.column].state == .hidden {
                toggleFlag(atRow: m.row, column: m.column)
                newlyFlagged.append(m)
                fairnessRecord.autoSolveCount += 1
            }
        }

        // 再揭開必然安全格
        for s in solverResult.sureSafeCells {
            if internalBoard[s.row, s.column].state == .hidden {
                revealCell(atRow: s.row, column: s.column)
                newlyRevealed.append(s)
                fairnessRecord.autoSolveCount += 1
            }
        }

        let isGuess = solverResult.status == .guessRequired && newlyRevealed.isEmpty && newlyFlagged.isEmpty
        return (newlyRevealed, newlyFlagged, isGuess)
    }

    /// 套用已由外部審查之修復棋盤 (例如玩家確認套用 AI 建議)
    public func applyRepairedBoard(_ newBoard: Board, movedMines: Int) {
        UndoRedoManager.shared.recordSnapshot(captureSnapshot(action: "套用棋盤修復"))
        self.internalBoard = newBoard
        self.fairnessRecord.repairCount += 1
        self.fairnessRecord.movedMinesCount += movedMines
    }

    // MARK: - 快照與 Undo / Redo 管理

    /// 截取當前遊戲快照
    public func captureSnapshot(action: String) -> GameSnapshot {
        GameSnapshot(
            actionDescription: action,
            board: internalBoard,
            state: state,
            explodedMineCount: explodedMineCount,
            pureElapsedTime: pureElapsedTime,
            fairnessRecord: fairnessRecord,
            difficulty: difficulty,
            mode: mode,
            seed: currentSeed
        )
    }

    /// 執行復原 (Undo)
    @discardableResult
    public func performUndo() -> Bool {
        guard let prev = UndoRedoManager.shared.performUndo(currentSnapshot: captureSnapshot(action: "復原前狀態")) else {
            return false
        }
        applySnapshot(prev)
        fairnessRecord.undoCount += 1
        ReplayEngine.shared.recordStep(
            actionType: .undo,
            coordinate: nil,
            description: "復原至：\(prev.actionDescription)",
            board: internalBoard,
            state: state,
            explodedCount: explodedMineCount
        )
        return true
    }

    /// 執行重做 (Redo)
    @discardableResult
    public func performRedo() -> Bool {
        guard let next = UndoRedoManager.shared.performRedo(currentSnapshot: captureSnapshot(action: "重做前狀態")) else {
            return false
        }
        applySnapshot(next)
        ReplayEngine.shared.recordStep(
            actionType: .redo,
            coordinate: nil,
            description: "重做至：\(next.actionDescription)",
            board: internalBoard,
            state: state,
            explodedCount: explodedMineCount
        )
        return true
    }

    /// 還原自快照實體
    public func applySnapshot(_ snapshot: GameSnapshot) {
        self.internalBoard = snapshot.board
        self.state = snapshot.state
        self.explodedMineCount = snapshot.explodedMineCount
        self.difficulty = snapshot.difficulty
        self.mode = snapshot.mode
        self.currentSeed = snapshot.seed
        self.simulatedElapsedTime = snapshot.pureElapsedTime
    }

    /// 從本機存檔還原整局遊戲
    public func restoreFromSavedData(_ data: SavedGameData) {
        self.difficulty = data.difficulty
        self.mode = data.mode
        self.currentSeed = data.seed
        self.state = data.state
        self.internalBoard = data.board
        self.explodedMineCount = data.explodedMineCount
        self.simulatedElapsedTime = data.elapsedTime
        self.fairnessRecord = data.fairnessRecord
        UndoRedoManager.shared.clear()
        for snap in data.undoStack {
            UndoRedoManager.shared.recordSnapshot(snap)
        }
    }

    // MARK: - AI 救援揭露 (AI Rescue Reveal)

    /// 執行 AI 救援揭露
    /// 嚴格由可信任的 GameEngine 尋找真實安全位置，明確標記並記入歷史，絕不移動地雷
    @discardableResult
    public func executeAIRescue() -> GridCoordinate? {
        guard state == .inProgress || state == .ready else { return nil }

        // 若尚未進行首步點擊，首步安全區保證任意格安全
        if state == .ready {
            revealCell(atRow: 0, column: 0)
            return GridCoordinate(0, 0)
        }

        // 尋找未翻開、未插旗且非地雷的真實安全格
        var candidateSafe: GridCoordinate?
        for r in 0..<internalBoard.rows {
            for c in 0..<internalBoard.columns {
                let cell = internalBoard[r, c]
                if cell.state == .hidden && !cell.hasMine {
                    candidateSafe = GridCoordinate(r, c)
                    break
                }
            }
            if candidateSafe != nil { break }
        }

        guard let target = candidateSafe else { return nil }

        UndoRedoManager.shared.recordSnapshot(captureSnapshot(action: "AI 救援揭露 (\(target.row), \(target.column))"))
        fairnessRecord.aiRescueCount += 1

        _ = executeReveal(row: target.row, column: target.column)

        ReplayEngine.shared.recordStep(
            actionType: .aiRescue,
            coordinate: target,
            description: "AI 救援：由引擎確認並翻開安全格 (\(target.row), \(target.column))",
            board: internalBoard,
            state: state,
            explodedCount: explodedMineCount
        )

        ReasoningHistoryManager.shared.addStep(
            ReasoningStep(
                method: "AI 救援",
                resultType: "安全格揭露",
                wasRepaired: false,
                detail: "因盤面陷入猜測死局，系統已啟動 AI 救援，揭露真實安全格 (\(target.row), \(target.column))。"
            )
        )

        return target
    }
}
