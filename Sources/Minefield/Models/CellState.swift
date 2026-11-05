import Foundation

/// 格子的四種核心顯示與互動狀態
public enum CellState: String, Codable, Sendable, Equatable {
    /// 未翻開 (初始狀態)
    case hidden
    /// 已插旗標記
    case flagged
    /// 已安全翻開，顯示周圍地雷數 (0~8)
    case revealed
    /// 踩中地雷 (爆炸狀態)
    case exploded
}
