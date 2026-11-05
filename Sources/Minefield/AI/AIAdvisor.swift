import Foundation

/// AI 提示與戰術助理介面 (以安全公開視圖 PublicCell 為基礎，保證不作弊)
public protocol AIAdvisorProtocol {
    func evaluateCurrentSituation(grid: [[PublicCell]]) -> String
}

public final class AIAdvisor: AIAdvisorProtocol {
    public init() {}

    public func evaluateCurrentSituation(grid: [[PublicCell]]) -> String {
        let revealedCount = grid.flatMap { $0 }.filter { $0.isRevealed }.count
        if revealedCount == 0 {
            return "棋局就緒，請點擊任一格子展開第一步。"
        }
        return "正在分析當前盤面，尋找最佳邏輯切入點..."
    }
}
