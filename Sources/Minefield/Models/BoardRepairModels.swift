import Foundation

/// 單一地雷移動向量
public struct MineMove: Equatable, Sendable, Identifiable {
    public var id: String { "\(from.row),\(from.column)->\(to.row),\(to.column)" }
    public let from: GridCoordinate
    public let to: GridCoordinate

    public init(from: GridCoordinate, to: GridCoordinate) {
        self.from = from
        self.to = to
    }
}

/// 棋盤修復方案
public struct BoardRepairPlan: Equatable, Sendable {
    public let moves: [MineMove]
    public let reason: String
    public let strategy: String
    public let targetSafeCells: [GridCoordinate]

    public init(
        moves: [MineMove],
        reason: String,
        strategy: String = "minimal_change",
        targetSafeCells: [GridCoordinate] = []
    ) {
        self.moves = moves
        self.reason = reason
        self.strategy = strategy
        self.targetSafeCells = targetSafeCells
    }
}

/// 棋盤修復執行與交易驗證報告
public struct BoardRepairResult: Equatable, Sendable {
    public let success: Bool
    public let movedMinesCount: Int
    public let moves: [MineMove]
    public let newSafeCells: [GridCoordinate]
    public let repairedBoard: Board?
    public let riskBefore: [String: Double]
    public let riskAfter: [String: Double]
    public let validationNotes: [String]
    public let errorMessage: String?

    public init(
        success: Bool,
        movedMinesCount: Int = 0,
        moves: [MineMove] = [],
        newSafeCells: [GridCoordinate] = [],
        repairedBoard: Board? = nil,
        riskBefore: [String: Double] = [:],
        riskAfter: [String: Double] = [:],
        validationNotes: [String] = [],
        errorMessage: String? = nil
    ) {
        self.success = success
        self.movedMinesCount = movedMinesCount
        self.moves = moves
        self.newSafeCells = newSafeCells
        self.repairedBoard = repairedBoard
        self.riskBefore = riskBefore
        self.riskAfter = riskAfter
        self.validationNotes = validationNotes
        self.errorMessage = errorMessage
    }

    public static func failure(reason: String) -> BoardRepairResult {
        BoardRepairResult(success: false, errorMessage: reason)
    }
}

// MARK: - AI 修復建議 JSON Schema 原始結構
public struct RawAIRepairSuggestion: Codable, Sendable {
    public let fromRow: Int
    public let fromCol: Int
    public let toRow: Int
    public let toCol: Int

    public init(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) {
        self.fromRow = fromRow
        self.fromCol = fromCol
        self.toRow = toRow
        self.toCol = toCol
    }
}

public struct RawAIRepairResponse: Codable, Sendable {
    public let analysis: String
    public let repair_strategy: String
    public let reasoning: String
    public let constraints: [String]
    public let suggestions: [RawAIRepairSuggestion]

    public init(
        analysis: String,
        repair_strategy: String = "minimal_change",
        reasoning: String,
        constraints: [String] = [],
        suggestions: [RawAIRepairSuggestion] = []
    ) {
        self.analysis = analysis
        self.repair_strategy = repair_strategy
        self.reasoning = reasoning
        self.constraints = constraints
        self.suggestions = suggestions
    }
}
