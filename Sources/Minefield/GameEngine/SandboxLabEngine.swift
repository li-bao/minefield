import Foundation

/// 棋盤分享資料載荷 (不洩露任何隱藏雷陣列，確保公平性)
public struct BoardSharePayload: Codable, Equatable, Sendable {
    public let version: Int
    public let width: Int
    public let height: Int
    public let mines: Int
    public let seed: UInt64
    public let modeRawValue: String

    public init(
        version: Int = 1,
        width: Int,
        height: Int,
        mines: Int,
        seed: UInt64,
        modeRawValue: String
    ) {
        self.version = version
        self.width = width
        self.height = height
        self.mines = mines
        self.seed = seed
        self.modeRawValue = modeRawValue
    }
}

/// 棋局分享代碼解析錯誤
public enum BoardShareError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedVersion
    case invalidDimensions(String)
    case invalidMineCount(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "棋局代碼格式無效，請確認複製正確的代碼。"
        case .unsupportedVersion:
            return "不支援的棋局代碼版本。"
        case .invalidDimensions(let msg):
            return "尺寸不合法：\(msg)"
        case .invalidMineCount(let msg):
            return "地雷配置不合法：\(msg)"
        }
    }
}

/// 棋盤代碼編碼與驗證器
public struct BoardShareCoder {
    /// 匯出為分享代碼 (格式: MF1-16x16-40-<HEX_SEED>-<MODE>)
    public static func encode(payload: BoardSharePayload) -> String {
        let hexSeed = String(payload.seed, radix: 16, uppercase: true)
        return "MF\(payload.version)-\(payload.width)x\(payload.height)-\(payload.mines)-\(hexSeed)-\(payload.modeRawValue)"
    }

    /// 解析並驗證棋盤代碼
    public static func decode(code: String) -> Result<BoardSharePayload, BoardShareError> {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-")
        guard parts.count >= 5 else {
            return .failure(.invalidFormat)
        }

        // 版本
        guard parts[0] == "MF1" else {
            return .failure(.unsupportedVersion)
        }

        // 尺寸
        let dimParts = parts[1].split(separator: "x")
        guard dimParts.count == 2,
              let w = Int(dimParts[0]),
              let h = Int(dimParts[1]) else {
            return .failure(.invalidFormat)
        }

        if w < CustomBoardConfig.minWidth || w > CustomBoardConfig.maxWidth ||
           h < CustomBoardConfig.minHeight || h > CustomBoardConfig.maxHeight {
            return .failure(.invalidDimensions("寬度需在 5~40，高度需在 5~30 之間"))
        }

        // 地雷數
        guard let m = Int(parts[2]) else {
            return .failure(.invalidFormat)
        }
        let maxM = CustomBoardConfig.maxMines(forWidth: w, height: h)
        if m < 1 || m > maxM {
            return .failure(.invalidMineCount("地雷需在 1 ~ \(maxM) 之間"))
        }

        // 種子 (Hex)
        guard let seed = UInt64(parts[3], radix: 16) else {
            return .failure(.invalidFormat)
        }

        // 模式
        let mode = String(parts[4])

        return .success(BoardSharePayload(
            version: 1,
            width: w,
            height: h,
            mines: m,
            seed: seed,
            modeRawValue: mode
        ))
    }
}

/// 沙盒實驗室引擎 (SandboxLabEngine)
/// 允許自由擺放地雷、測試 Solver、驗證 No-Guess 與修復演算法
public final class SandboxLabEngine: ObservableObject {
    @Published public var board: Board
    @Published public var seed: UInt64
    @Published public private(set) var lastSolverResult: SolverResult?
    @Published public private(set) var lastHeatmapReport: HeatmapReport?
    @Published public private(set) var isSolvableWithoutGuess: Bool?

    public init(rows: Int = 9, columns: Int = 9, mines: Int = 10, seed: UInt64 = 12345) {
        self.seed = seed
        self.board = Board(rows: rows, columns: columns, totalMines: mines)
        recalculateNumbers()
    }

    /// 重設棋盤尺寸
    public func resetDimensions(rows: Int, columns: Int, mines: Int) {
        self.board = Board(rows: rows, columns: columns, totalMines: mines)
        recalculateNumbers()
        self.lastSolverResult = nil
        self.lastHeatmapReport = nil
        self.isSolvableWithoutGuess = nil
    }

    /// 手動切換某格地雷存在狀態
    public func toggleMine(row: Int, column: Int) {
        guard board.isValidCoordinate(row: row, column: column) else { return }
        board[row, column].hasMine.toggle()
        recalculateNumbers()
    }

    /// 手動切換格子翻開/隱藏 (沙盒模擬測試)
    public func toggleReveal(row: Int, column: Int) {
        guard board.isValidCoordinate(row: row, column: column) else { return }
        if board[row, column].state == .hidden {
            board[row, column].state = .revealed
        } else {
            board[row, column].state = .hidden
        }
    }

    /// 重新計算全盤相鄰雷數
    public func recalculateNumbers() {
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

    /// 執行求解器分析
    public func runSolverAnalysis() -> SolverResult {
        let result = SmartSolver.shared.analyze(
            grid: board.toPublicGrid(),
            totalMines: board.totalMines,
            flaggedCount: board.flaggedCount
        )
        self.lastSolverResult = result
        return result
    }

    /// 執行風險熱力圖分析
    public func runProbabilityAnalysis() -> HeatmapReport {
        let report = ProbabilityCalculator.shared.generateHeatmap(
            grid: board.toPublicGrid(),
            totalMines: board.totalMines,
            flaggedCount: board.flaggedCount,
            solverResult: lastSolverResult
        )
        self.lastHeatmapReport = report
        return report
    }

    /// 執行無猜可解性模擬驗證
    public func verifyNoGuess(firstClick: GridCoordinate) -> Bool {
        let solvable = NoGuessBoardGenerator.shared.isNaturallySolvableWithoutGuess(
            board: board,
            firstClick: (firstClick.row, firstClick.column)
        )
        self.isSolvableWithoutGuess = solvable
        return solvable
    }

    /// 產生當前沙盒設定之分享碼
    public func exportShareCode() -> String {
        let payload = BoardSharePayload(
            width: board.columns,
            height: board.rows,
            mines: board.totalMines,
            seed: seed,
            modeRawValue: "沙盒模式"
        )
        return BoardShareCoder.encode(payload: payload)
    }

    /// 匯入分享碼
    public func importShareCode(_ code: String) -> Result<Void, BoardShareError> {
        switch BoardShareCoder.decode(code: code) {
        case .success(let payload):
            self.seed = payload.seed
            resetDimensions(rows: payload.height, columns: payload.width, mines: payload.mines)
            return .success(())
        case .failure(let err):
            return .failure(err)
        }
    }
}
