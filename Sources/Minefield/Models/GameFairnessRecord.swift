import Foundation

/// 棋局公平性與詳細操作統計記錄
public struct GameFairnessRecord: Codable, Equatable, Sendable {
    /// 棋盤初始隨機種子
    public var seed: UInt64
    /// 棋盤執行修復次數
    public var repairCount: Int
    /// 累計移動的地雷總顆數
    public var movedMinesCount: Int
    /// 玩家主動使用提示次數
    public var hintCount: Int
    /// AI 專家介入採納次數
    public var aiInterventionCount: Int
    /// 自動排雷操作次數
    public var autoSolveCount: Int
    /// 復原 Undo 操作次數
    public var undoCount: Int
    /// AI 救援揭露次數
    public var aiRescueCount: Int
    /// 純遊玩經過時間 (秒)
    public var pureElapsedTime: TimeInterval
    /// 總計時 (含踩雷懲罰)
    public var totalTimeWithPenalties: TimeInterval

    /// 是否為純粹未經任何 AI 或系統修復的「經典有效紀錄」
    public var isPureClassicValid: Bool {
        repairCount == 0 &&
        movedMinesCount == 0 &&
        aiInterventionCount == 0 &&
        autoSolveCount == 0 &&
        undoCount == 0 &&
        aiRescueCount == 0
    }

    public init(
        seed: UInt64 = 0,
        repairCount: Int = 0,
        movedMinesCount: Int = 0,
        hintCount: Int = 0,
        aiInterventionCount: Int = 0,
        autoSolveCount: Int = 0,
        undoCount: Int = 0,
        aiRescueCount: Int = 0,
        pureElapsedTime: TimeInterval = 0.0,
        totalTimeWithPenalties: TimeInterval = 0.0
    ) {
        self.seed = seed
        self.repairCount = repairCount
        self.movedMinesCount = movedMinesCount
        self.hintCount = hintCount
        self.aiInterventionCount = aiInterventionCount
        self.autoSolveCount = autoSolveCount
        self.undoCount = undoCount
        self.aiRescueCount = aiRescueCount
        self.pureElapsedTime = pureElapsedTime
        self.totalTimeWithPenalties = totalTimeWithPenalties
    }

    public mutating func reset(seed: UInt64) {
        self.seed = seed
        self.repairCount = 0
        self.movedMinesCount = 0
        self.hintCount = 0
        self.aiInterventionCount = 0
        self.autoSolveCount = 0
        self.undoCount = 0
        self.aiRescueCount = 0
        self.pureElapsedTime = 0.0
        self.totalTimeWithPenalties = 0.0
    }
}
