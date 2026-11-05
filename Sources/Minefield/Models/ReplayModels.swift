import Foundation

/// 回放動作類型
public enum ReplayActionType: String, Codable, Sendable {
    case gameStart = "遊戲開始"
    case reveal = "翻開格子"
    case flag = "插旗標記"
    case unflag = "取消插旗"
    case chord = "和弦連鎖翻開"
    case hint = "索取提示"
    case solverAnalyze = "求解器分析"
    case aiAnalyze = "AI 專家分析"
    case aiRescue = "AI 救援揭露"
    case repair = "棋局修復"
    case undo = "操作復原"
    case redo = "操作重做"
    case gameWon = "遊戲勝利"
    case gameLost = "踩雷失敗"
}

/// 回放單一步驟操作紀錄
public struct ReplayStep: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let stepIndex: Int
    public let timestamp: TimeInterval // 自遊戲開始起算的相對秒數
    public let actionType: ReplayActionType
    public let coordinate: GridCoordinate?
    public let description: String
    /// 該步驟執行後的盤面快照
    public let boardSnapshot: Board
    public let stateSnapshot: GameState
    public let explodedCount: Int

    public init(
        id: UUID = UUID(),
        stepIndex: Int,
        timestamp: TimeInterval,
        actionType: ReplayActionType,
        coordinate: GridCoordinate? = nil,
        description: String,
        boardSnapshot: Board,
        stateSnapshot: GameState,
        explodedCount: Int = 0
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.timestamp = timestamp
        self.actionType = actionType
        self.coordinate = coordinate
        self.description = description
        self.boardSnapshot = boardSnapshot
        self.stateSnapshot = stateSnapshot
        self.explodedCount = explodedCount
    }
}

/// 完整棋局回放記錄
public struct ReplayGameRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let difficulty: GameDifficulty
    public let mode: GameMode
    public let seed: UInt64
    public let totalTime: TimeInterval
    public let finalState: GameState
    public let initialBoard: Board
    public let steps: [ReplayStep]
    public let fairnessRecord: GameFairnessRecord

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        difficulty: GameDifficulty,
        mode: GameMode,
        seed: UInt64,
        totalTime: TimeInterval,
        finalState: GameState,
        initialBoard: Board,
        steps: [ReplayStep],
        fairnessRecord: GameFairnessRecord
    ) {
        self.id = id
        self.createdAt = createdAt
        self.difficulty = difficulty
        self.mode = mode
        self.seed = seed
        self.totalTime = totalTime
        self.finalState = finalState
        self.initialBoard = initialBoard
        self.steps = steps
        self.fairnessRecord = fairnessRecord
    }
}
