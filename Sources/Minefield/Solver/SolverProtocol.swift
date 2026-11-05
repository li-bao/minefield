import Foundation

/// 掃雷自動求解與 CSP 約束滿足演算法介面
/// 只能接收 PublicCell 安全投影視圖，嚴格保證不讀取機密地雷陣列
public protocol SolverProtocol: Sendable {
    /// 完整分析目前盤面，回傳所有推導出的機率、確定解與推薦操作
    func analyze(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int
    ) -> SolverResult
}
