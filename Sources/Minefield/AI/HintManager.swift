import Foundation

/// 提示等級
public enum HintLevel: Int, CaseIterable, Identifiable, Sendable {
    case direction = 1
    case reasoning = 2
    case position = 3
    case fullDeduction = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .direction: return "Level 1: 方向提示"
        case .reasoning: return "Level 2: 推理提示"
        case .position: return "Level 3: 位置提示"
        case .fullDeduction: return "Level 4: 完整解析"
        }
    }
}

/// 提示分類
public enum HintCategory: String, Sendable {
    case sureSafe = "必然安全"
    case sureMine = "必然地雷"
    case lowestRisk = "最低風險"
    case bestInformationGain = "最佳資訊價值"
    case guessRequired = "猜測風險警示"
    case noMoves = "無提示標的"
}

/// 多層級提示報告
public struct MultiLevelHint: Equatable, Sendable {
    public let category: HintCategory
    public let targetCoordinate: GridCoordinate?
    public let action: RecommendedAction
    public let probability: Double
    public let directionText: String
    public let reasoningText: String
    public let positionText: String
    public let fullDeductionText: String
    public let highlightedCoordinates: [GridCoordinate]

    public init(
        category: HintCategory,
        targetCoordinate: GridCoordinate?,
        action: RecommendedAction,
        probability: Double,
        directionText: String,
        reasoningText: String,
        positionText: String,
        fullDeductionText: String,
        highlightedCoordinates: [GridCoordinate]
    ) {
        self.category = category
        self.targetCoordinate = targetCoordinate
        self.action = action
        self.probability = probability
        self.directionText = directionText
        self.reasoningText = reasoningText
        self.positionText = positionText
        self.fullDeductionText = fullDeductionText
        self.highlightedCoordinates = highlightedCoordinates
    }

    /// 根據指定等級取得說明文字
    public func text(for level: HintLevel) -> String {
        switch level {
        case .direction: return directionText
        case .reasoning: return reasoningText
        case .position: return positionText
        case .fullDeduction: return fullDeductionText
        }
    }
}

/// 高級多層次提示管理引擎 (Hint Manager)
public final class HintManager: Sendable {
    public static let shared = HintManager()

    public init() {}

    /// 產生 4 級遞進提示
    public func generateHint(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int
    ) -> MultiLevelHint {
        let solverResult = SmartSolver.shared.analyze(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount)
        let heatmap = ProbabilityCalculator.shared.generateHeatmap(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount, solverResult: solverResult)

        // 優先順序 1：必然安全格
        if let safe = solverResult.sureSafeCells.first {
            let region = describeRegion(row: safe.row, col: safe.column, totalRows: grid.count, totalCols: grid.first?.count ?? 0)
            return MultiLevelHint(
                category: .sureSafe,
                targetCoordinate: safe,
                action: .reveal,
                probability: 0.0,
                directionText: "請將注意力集中在【\(region)】，那裡的數字已經給出充分線索。",
                reasoningText: "觀察該區數字，相鄰已標記地雷數已滿足要求，周圍存在至少一個必然無雷的空格。",
                positionText: "建議操作位置：座標 (\(safe.row), \(safe.column))，動作：【翻開】。",
                fullDeductionText: "【數學推導】根據數字格約束與相鄰已插旗數完全匹配，座標 (\(safe.row), \(safe.column)) 之地雷率嚴格為 0.0%，點擊必然安全。",
                highlightedCoordinates: [safe]
            )
        }

        // 優先順序 2：必然地雷格
        if let mine = solverResult.sureMineCells.first {
            let region = describeRegion(row: mine.row, col: mine.column, totalRows: grid.count, totalCols: grid.first?.count ?? 0)
            return MultiLevelHint(
                category: .sureMine,
                targetCoordinate: mine,
                action: .flag,
                probability: 1.0,
                directionText: "請留意【\(region)】，該區域存在被數字嚴格夾擠的地雷。",
                reasoningText: "該處數字所需的剩餘地雷數與周圍剩餘未翻開格數量完全一致（鴿籠原理）。",
                positionText: "建議操作位置：座標 (\(mine.row), \(mine.column))，動作：【插旗標記】。",
                fullDeductionText: "【數學推導】周圍可容納雷的空格數恰好等於未滿足的地雷額度，該格為雷之機率為 100.0%，建議插旗標記避免誤踩。",
                highlightedCoordinates: [mine]
            )
        }

        // 優先順序 3：需要猜測時之最低風險 / 最佳資訊價值格
        if let rec = heatmap.recommendedMove {
            let region = describeRegion(row: rec.coordinate.row, col: rec.coordinate.column, totalRows: grid.count, totalCols: grid.first?.count ?? 0)
            let riskPct = String(format: "%.1f", rec.probability * 100.0)
            return MultiLevelHint(
                category: .lowestRisk,
                targetCoordinate: rec.coordinate,
                action: .guess,
                probability: rec.probability,
                directionText: "目前盤面無 100% 確定解。請考慮觀察【\(region)】的未知邊緣。",
                reasoningText: "該處未知格子經連通分支枚舉，具有全盤最低之地雷風險 (\(riskPct)%)，且能帶來最大資訊價值。",
                positionText: "若決定推進，相對最優位置為：座標 (\(rec.coordinate.row), \(rec.coordinate.column))。",
                fullDeductionText: "【機率分析】窮舉合法配置後確認此局需要猜測。此格地雷機率僅 \(riskPct)%，且揭露後預期消除最大不確定性 (資訊熵 \(String(format: "%.2f", rec.informationGain)))。",
                highlightedCoordinates: [rec.coordinate]
            )
        }

        // 無分析標的
        return MultiLevelHint(
            category: .noMoves,
            targetCoordinate: nil,
            action: .guess,
            probability: 0.0,
            directionText: "目前盤面無特定聚焦區域。",
            reasoningText: "無可推導的約束數字。",
            positionText: "可點擊任一未揭開方格以開闢新局。",
            fullDeductionText: "首發點擊享有安全區保護，可隨機選點展開。",
            highlightedCoordinates: []
        )
    }

    private func describeRegion(row: Int, col: Int, totalRows: Int, totalCols: Int) -> String {
        guard totalRows > 0 && totalCols > 0 else { return "棋盤中央" }
        let vertical = row < totalRows / 3 ? "上方" : (row > totalRows * 2 / 3 ? "下方" : "中央")
        let horizontal = col < totalCols / 3 ? "左側" : (col > totalCols * 2 / 3 ? "右側" : "中間")
        return "棋盤\(vertical)\(horizontal)"
    }
}
