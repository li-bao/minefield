import Foundation

/// 智慧排雷結果整體狀態
public enum SolverStatus: String, Codable, Sendable, Equatable {
    /// 存在必然安全的格子 (0% 地雷風險)
    case safe = "必然安全"
    /// 存在必然是雷的格子 (100% 地雷風險，建議插旗)
    case mine = "必然地雷"
    /// 無任何確定解，目前棋局必須進行猜測
    case guessRequired = "需要猜測"
    /// 搜尋資源達到上限，分析結果為不完整
    case incomplete = "計算不完整"
    /// 目前盤面無可行分析 (例如剛開局或已結束)
    case noMovesPossible = "無分析標的"
}

/// 建議操作類型
public enum RecommendedAction: String, Codable, Sendable, Equatable {
    case reveal = "翻開"
    case flag = "插旗"
    case guess = "謹慎嘗試"
}

/// 棋盤座標點實體
public struct GridCoordinate: Equatable, Hashable, Sendable, Identifiable, Codable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public init(_ row: Int, _ column: Int) {
        self.row = row
        self.column = column
    }
}

/// 候選猜測格風險資訊
public struct RiskCandidate: Equatable, Sendable, Identifiable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int
    public let risk: Double

    public init(row: Int, column: Int, risk: Double) {
        self.row = row
        self.column = column
        self.risk = risk
    }
}

/// 格子推導建議內容
public struct CellRecommendation: Identifiable, Equatable, Sendable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int
    public let action: RecommendedAction
    /// 真正的地雷機率 (0.0 為絕對安全，1.0 為絕對地雷)
    public let mineProbability: Double
    /// 推理依據說明 (繁體中文)
    public let reason: String

    public init(
        row: Int,
        column: Int,
        action: RecommendedAction,
        mineProbability: Double,
        reason: String
    ) {
        self.row = row
        self.column = column
        self.action = action
        self.mineProbability = mineProbability
        self.reason = reason
    }
}

/// 單一未知格子的推導機率資訊
public struct CellProbability: Identifiable, Equatable, Sendable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int
    /// 0.0 ~ 1.0 地雷機率
    public let mineProbability: Double

    public var isCertainSafe: Bool {
        abs(mineProbability) < 1e-6
    }

    public var isCertainMine: Bool {
        abs(mineProbability - 1.0) < 1e-6
    }

    public init(row: Int, column: Int, mineProbability: Double) {
        self.row = row
        self.column = column
        self.mineProbability = mineProbability
    }
}

/// 求解器全面分析報告
public struct SolverResult: Equatable, Sendable {
    public let status: SolverStatus
    /// 每個未知格子的推導地雷機率 (以 "row,column" 為 key)
    public let probabilities: [String: CellProbability]
    /// 首選推薦動作 (依照安全優先 -> 插旗優先 -> 最低風險之順序)
    public let recommendedMove: CellRecommendation?
    /// 確定安全的所有格子座標
    public let sureSafeCells: [GridCoordinate]
    /// 確定地雷的所有格子座標
    public let sureMineCells: [GridCoordinate]
    /// 最低風險的候選格子 (在需要猜測時提供)
    public let lowestRiskCells: [RiskCandidate]
    /// 是否因資源上限提前終止
    public let isIncomplete: Bool
    /// 整體結論文字摘要 (繁體中文)
    public let summary: String

    public init(
        status: SolverStatus,
        probabilities: [String: CellProbability],
        recommendedMove: CellRecommendation?,
        sureSafeCells: [GridCoordinate],
        sureMineCells: [GridCoordinate],
        lowestRiskCells: [RiskCandidate],
        isIncomplete: Bool,
        summary: String
    ) {
        self.status = status
        self.probabilities = probabilities
        self.recommendedMove = recommendedMove
        self.sureSafeCells = sureSafeCells
        self.sureMineCells = sureMineCells
        self.lowestRiskCells = lowestRiskCells
        self.isIncomplete = isIncomplete
        self.summary = summary
    }

    public static func empty(summary: String = "無可分析資料") -> SolverResult {
        SolverResult(
            status: .noMovesPossible,
            probabilities: [:],
            recommendedMove: nil,
            sureSafeCells: [],
            sureMineCells: [],
            lowestRiskCells: [],
            isIncomplete: false,
            summary: summary
        )
    }
}
