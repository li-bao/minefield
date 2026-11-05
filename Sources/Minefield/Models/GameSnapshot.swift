import Foundation

/// 遊戲狀態時間點快照 (供 Undo / Redo 與存檔管理)
public struct GameSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let actionDescription: String
    public let board: Board
    public let state: GameState
    public let explodedMineCount: Int
    public let pureElapsedTime: TimeInterval
    public let fairnessRecord: GameFairnessRecord
    public let difficulty: GameDifficulty
    public let mode: GameMode
    public let seed: UInt64

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionDescription: String,
        board: Board,
        state: GameState,
        explodedMineCount: Int,
        pureElapsedTime: TimeInterval,
        fairnessRecord: GameFairnessRecord,
        difficulty: GameDifficulty,
        mode: GameMode,
        seed: UInt64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionDescription = actionDescription
        self.board = board
        self.state = state
        self.explodedMineCount = explodedMineCount
        self.pureElapsedTime = pureElapsedTime
        self.fairnessRecord = fairnessRecord
        self.difficulty = difficulty
        self.mode = mode
        self.seed = seed
    }
}
