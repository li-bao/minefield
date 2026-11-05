import Foundation

/// 棋盤單格詳細機率與資訊價值度量
public struct DetailedCellRisk: Identifiable, Equatable, Sendable {
    public var id: String { "\(coordinate.row),\(coordinate.column)" }
    public let coordinate: GridCoordinate
    /// 地雷機率 (0.0 ~ 1.0)
    public let probability: Double
    /// 是否為精確數學解 (若因超出搜尋上限或近似估算則為 false)
    public let isExact: Bool
    /// 計算方式標籤 (例如 "直接推導", "CSP 精確枚舉", "全域背景機率", "啟發式近似")
    public let computationMethod: String
    /// 資訊熵 (Shannon Entropy) 衡量揭露此格之資訊價值：-p log2(p) - (1-p) log2(1-p)
    public let informationGain: Double

    public init(
        coordinate: GridCoordinate,
        probability: Double,
        isExact: Bool,
        computationMethod: String
    ) {
        self.coordinate = coordinate
        self.probability = probability
        self.isExact = isExact
        self.computationMethod = computationMethod

        // 計算資訊熵 (0% 與 100% 資訊熵為 0，50% 達到最大 1.0)
        let p = max(1e-9, min(1.0 - 1e-9, probability))
        let entropy = -(p * log2(p) + (1.0 - p) * log2(1.0 - p))
        self.informationGain = (abs(probability) < 1e-6 || abs(probability - 1.0) < 1e-6) ? 0.0 : entropy
    }
}

/// 風險等級分類
public enum RiskCategory: String, Sendable, CaseIterable {
    case safe = "0% 必然安全"
    case low = "低風險 (<25%)"
    case medium = "中度風險 (25~60%)"
    case high = "高風險 (>60%)"
    case mine = "100% 必然地雷"
    case incomplete = "近似/計算不完全"
}

/// 全盤風險熱力與最佳操作排序分析報告
public struct HeatmapReport: Equatable, Sendable {
    public let detailedRisks: [String: DetailedCellRisk]
    public let safestCells: [DetailedCellRisk]
    public let mostDangerousCells: [DetailedCellRisk]
    public let bestInfoGainCells: [DetailedCellRisk]
    public let recommendedMove: DetailedCellRisk?
    public let hasExactGuarantee: Bool
    public let globalRemainingMines: Int
    public let globalHiddenCount: Int

    public init(
        detailedRisks: [String: DetailedCellRisk],
        safestCells: [DetailedCellRisk],
        mostDangerousCells: [DetailedCellRisk],
        bestInfoGainCells: [DetailedCellRisk],
        recommendedMove: DetailedCellRisk?,
        hasExactGuarantee: Bool,
        globalRemainingMines: Int,
        globalHiddenCount: Int
    ) {
        self.detailedRisks = detailedRisks
        self.safestCells = safestCells
        self.mostDangerousCells = mostDangerousCells
        self.bestInfoGainCells = bestInfoGainCells
        self.recommendedMove = recommendedMove
        self.hasExactGuarantee = hasExactGuarantee
        self.globalRemainingMines = globalRemainingMines
        self.globalHiddenCount = globalHiddenCount
    }
}

/// 高級機率與風險熱力圖計算引擎
public final class ProbabilityCalculator: Sendable {
    public static let shared = ProbabilityCalculator()

    public init() {}

    /// 根據公開盤面與求解器結果產生完整風險熱力分析
    public func generateHeatmap(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int,
        solverResult: SolverResult? = nil
    ) -> HeatmapReport {
        let solver = solverResult ?? SmartSolver.shared.analyze(
            grid: grid,
            totalMines: totalMines,
            flaggedCount: flaggedCount
        )

        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        var detailed: [String: DetailedCellRisk] = [:]

        var totalHidden = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c].isHidden {
                    totalHidden += 1
                }
            }
        }
        let remainingMines = max(0, totalMines - flaggedCount)

        // 整理已知機率
        for (key, cellProb) in solver.probabilities {
            let coord = GridCoordinate(cellProb.row, cellProb.column)
            let isExact = !solver.isIncomplete
            let method: String
            if cellProb.isCertainSafe {
                method = "直接邏輯約束 (0% 安全)"
            } else if cellProb.isCertainMine {
                method = "直接邏輯約束 (100% 地雷)"
            } else if !solver.isIncomplete {
                method = "CSP 連通區塊精確枚舉"
            } else {
                method = "受限搜尋近似估算"
            }

            detailed[key] = DetailedCellRisk(
                coordinate: coord,
                probability: cellProb.mineProbability,
                isExact: isExact,
                computationMethod: method
            )
        }

        // 針對未列入連通區塊的孤立未知格進行背景全域估計
        let backgroundProb: Double = totalHidden > 0 ? min(1.0, max(0.0, Double(remainingMines) / Double(totalHidden))) : 0.0
        for r in 0..<rows {
            for c in 0..<cols {
                let key = "\(r),\(c)"
                if grid[r][c].isHidden && detailed[key] == nil {
                    detailed[key] = DetailedCellRisk(
                        coordinate: GridCoordinate(r, c),
                        probability: backgroundProb,
                        isExact: !solver.isIncomplete,
                        computationMethod: "背景全域地雷分佈機率"
                    )
                }
            }
        }

        let allRisks = Array(detailed.values)

        // 安全排序 (機率越小越優先)
        let safest = allRisks.filter { $0.probability < 0.5 }.sorted { $0.probability < $1.probability }
        // 危險排序 (機率越大越優先)
        let mostDangerous = allRisks.filter { $0.probability > 0.5 }.sorted { $0.probability > $1.probability }
        // 資訊價值最高排序 (Entropy 越大越優先)
        let bestInfo = allRisks.sorted { $0.informationGain > $1.informationGain }

        // 最推薦動作：若有 0% 則選 0%，若無則選最低風險中資訊價值最佳者
        let recommended: DetailedCellRisk?
        if let sureSafe = safest.first(where: { abs($0.probability) < 1e-6 }) {
            recommended = sureSafe
        } else {
            recommended = safest.first ?? allRisks.sorted(by: { $0.probability < $1.probability }).first
        }

        return HeatmapReport(
            detailedRisks: detailed,
            safestCells: safest,
            mostDangerousCells: mostDangerous,
            bestInfoGainCells: bestInfo,
            recommendedMove: recommended,
            hasExactGuarantee: !solver.isIncomplete,
            globalRemainingMines: remainingMines,
            globalHiddenCount: totalHidden
        )
    }
}
