import Foundation

/// 單一推理決策或棋盤變動歷史紀錄
public struct ReasoningStep: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    /// 所依據的數字限制說明
    public let constraintsUsed: [String]
    /// 使用的推理方法 (例如: "直接約束推導", "集合包含相減", "CSP 連通分群回溯", "動態棋盤防猜修復")
    public let method: String
    /// 推理結果標籤 ("必然安全", "必然地雷", "需要猜測", "棋盤已修復")
    public let resultType: String
    /// 目標座標
    public let targetCell: GridCoordinate?
    /// 地雷風險百分比 (若適用)
    public let riskPercentage: Double?
    /// 是否引發棋局修復
    public let wasRepaired: Bool
    /// 詳細繁體中文說明
    public let detail: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        constraintsUsed: [String] = [],
        method: String,
        resultType: String,
        targetCell: GridCoordinate? = nil,
        riskPercentage: Double? = nil,
        wasRepaired: Bool = false,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.constraintsUsed = constraintsUsed
        self.method = method
        self.resultType = resultType
        self.targetCell = targetCell
        self.riskPercentage = riskPercentage
        self.wasRepaired = wasRepaired
        self.detail = detail
    }
}
