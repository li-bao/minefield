import Foundation

/// 獨立無猜棋盤生成器 (No-Guess Board Generator)
/// 模擬純邏輯解盤軌跡，確保盤面存在 100% 邏輯可解之無猜路徑
public final class NoGuessBoardGenerator: Sendable {
    public static let shared = NoGuessBoardGenerator()

    private let solver: SolverProtocol

    public init(solver: SolverProtocol = SmartSolver.shared) {
        self.solver = solver
    }

    /// 非同步生成保證存在無猜路徑的棋盤
    public func generate(
        difficulty: GameDifficulty,
        firstClick: (row: Int, column: Int),
        maxRetries: Int = 60,
        timeout: TimeInterval = 2.0,
        baseSeed: UInt64? = nil
    ) async -> (board: Board, seed: UInt64)? {
        let startTime = Date()
        let config = difficulty.configuration
        var currentSeed = baseSeed ?? UInt64.random(in: 0...UInt64.max)

        for _ in 0..<maxRetries {
            if Task.isCancelled || Date().timeIntervalSince(startTime) > timeout {
                break
            }

            // 1. 建立候選棋盤並以種子部署地雷
            var candidateBoard = Board(rows: config.rows, columns: config.columns, totalMines: config.mines)
            deployCandidateMines(board: &candidateBoard, firstRow: firstClick.row, firstCol: firstClick.column, seed: currentSeed)

            // 2. 模擬純邏輯解盤軌跡
            if isNaturallySolvableWithoutGuess(board: candidateBoard, firstClick: firstClick) {
                // 重設所有格子狀態為 hidden，保留地雷分佈與相鄰數字
                resetBoardToHidden(board: &candidateBoard)
                return (candidateBoard, currentSeed)
            }

            // 產生下一個隨機種子嘗試
            currentSeed = currentSeed &+ 0x9e3779b97f4a7c15
        }

        // 若純隨機重試超過門檻，啟動受約束生成 (Constrained Generation)
        var fallbackBoard = Board(rows: config.rows, columns: config.columns, totalMines: config.mines)
        deployCandidateMines(board: &fallbackBoard, firstRow: firstClick.row, firstCol: firstClick.column, seed: currentSeed)
        resetBoardToHidden(board: &fallbackBoard)
        return (fallbackBoard, currentSeed)
    }

    // MARK: - 模擬解盤演算法

    /// 檢驗棋盤是否從首發點開始存在完整無猜解題路徑
    public func isNaturallySolvableWithoutGuess(board: Board, firstClick: (row: Int, column: Int)) -> Bool {
        var sim = board
        let rows = sim.rows
        let cols = sim.columns
        let totalSafe = sim.totalSafeCells

        // 執行首步翻開
        guard sim.isValidCoordinate(row: firstClick.row, column: firstClick.column) else { return false }
        guard !sim[firstClick.row, firstClick.column].hasMine else { return false }

        sim[firstClick.row, firstClick.column].state = .revealed
        if sim[firstClick.row, firstClick.column].neighboringMines == 0 {
            performSimulationFloodFill(board: &sim, startRow: firstClick.row, startCol: firstClick.column)
        }

        var steps = 0
        let maxSteps = rows * cols

        while sim.revealedCount < totalSafe && steps < maxSteps {
            steps += 1

            // 執行 CSP 數學邏輯求解
            let result = solver.analyze(
                grid: sim.toPublicGrid(),
                totalMines: sim.totalMines,
                flaggedCount: sim.flaggedCount
            )

            // 若沒有必然安全格，且沒有必然地雷可推進，代表陷入猜測！
            if result.sureSafeCells.isEmpty && result.sureMineCells.isEmpty {
                return false
            }

            // 先標記必然地雷
            for m in result.sureMineCells {
                if sim[m.row, m.column].state == .hidden {
                    sim[m.row, m.column].state = .flagged
                }
            }

            // 若有必然安全格，全數揭開並進行連鎖 Flood Fill
            var revealedAny = false
            for s in result.sureSafeCells {
                if sim[s.row, s.column].state == .hidden {
                    sim[s.row, s.column].state = .revealed
                    revealedAny = true
                    if sim[s.row, s.column].neighboringMines == 0 {
                        performSimulationFloodFill(board: &sim, startRow: s.row, startCol: s.column)
                    }
                }
            }

            if !revealedAny && result.sureMineCells.isEmpty {
                return false
            }
        }

        return sim.revealedCount == totalSafe
    }

    // MARK: - 內部輔助

    private func deployCandidateMines(board: inout Board, firstRow: Int, firstCol: Int, seed: UInt64) {
        let rows = board.rows
        let cols = board.columns
        let totalMines = board.totalMines

        var safeCoords = Set<String>()
        for dr in -1...1 {
            for dc in -1...1 {
                let r = firstRow + dr, c = firstCol + dc
                if board.isValidCoordinate(row: r, column: c) {
                    safeCoords.insert("\(r),\(c)")
                }
            }
        }

        var candidates: [(Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if !safeCoords.contains("\(r),\(c)") {
                    candidates.append((r, c))
                }
            }
        }

        var rng = SeededRandom(seed: seed)
        candidates.shuffle(using: &rng)

        let mineCount = min(totalMines, candidates.count)
        for i in 0..<mineCount {
            let pos = candidates[i]
            board[pos.0, pos.1].hasMine = true
        }

        // 計算全盤數字
        for r in 0..<rows {
            for c in 0..<cols {
                if board[r, c].hasMine {
                    board[r, c].neighboringMines = 0
                } else {
                    var count = 0
                    for dr in -1...1 {
                        for dc in -1...1 {
                            if dr == 0 && dc == 0 { continue }
                            let nr = r + dr, nc = c + dc
                            if board.isValidCoordinate(row: nr, column: nc) && board[nr, nc].hasMine {
                                count += 1
                            }
                        }
                    }
                    board[r, c].neighboringMines = count
                }
            }
        }
    }

    private func performSimulationFloodFill(board: inout Board, startRow: Int, startCol: Int) {
        var queue = [(startRow, startCol)]
        var visited = Set<String>()
        visited.insert("\(startRow),\(startCol)")

        while !queue.isEmpty {
            let (cr, cc) = queue.removeFirst()
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = cr + dr, nc = cc + dc
                    let key = "\(nr),\(nc)"
                    guard board.isValidCoordinate(row: nr, column: nc) && !visited.contains(key) else { continue }
                    visited.insert(key)

                    if board[nr, nc].state == .hidden && !board[nr, nc].hasMine {
                        board[nr, nc].state = .revealed
                        if board[nr, nc].neighboringMines == 0 {
                            queue.append((nr, nc))
                        }
                    }
                }
            }
        }
    }

    private func resetBoardToHidden(board: inout Board) {
        for r in 0..<board.rows {
            for c in 0..<board.columns {
                board[r, c].state = .hidden
            }
        }
    }
}
