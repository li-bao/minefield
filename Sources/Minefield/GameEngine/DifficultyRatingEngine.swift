import Foundation

/// 難度評估階級
public enum DifficultyTier: String, CaseIterable, Sendable {
    case beginner = "新手 (Beginner 1~25分)"
    case intermediate = "中等 (Intermediate 26~50分)"
    case advanced = "進階 (Advanced 51~75分)"
    case expert = "專家 (Expert 76~90分)"
    case master = "大師 (Master 91~100分)"
}

/// 棋盤複雜度與難度評估報告
public struct DifficultyRatingReport: Equatable, Sendable {
    /// 1 ~ 100 分數
    public let score: Int
    public let tier: DifficultyTier
    public let frontierSize: Int
    public let maxConstraintVariables: Int
    public let techniquesRequired: [String]
    public let summary: String

    public init(
        score: Int,
        tier: DifficultyTier,
        frontierSize: Int,
        maxConstraintVariables: Int,
        techniquesRequired: [String],
        summary: String
    ) {
        self.score = score
        self.tier = tier
        self.frontierSize = frontierSize
        self.maxConstraintVariables = maxConstraintVariables
        self.techniquesRequired = techniquesRequired
        self.summary = summary
    }
}

/// 遊戲難度演算法評估引擎 (Difficulty Rating Engine)
public final class DifficultyRatingEngine: Sendable {
    public static let shared = DifficultyRatingEngine()

    public init() {}

    /// 評估目前公開盤面之客觀難度
    public func evaluateDifficulty(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int
    ) -> DifficultyRatingReport {
        let rows = grid.count
        guard rows > 0 else {
            return DifficultyRatingReport(score: 10, tier: .beginner, frontierSize: 0, maxConstraintVariables: 0, techniquesRequired: ["首步開局"], summary: "剛開局，難度極低。")
        }
        let cols = grid[0].count
        let totalCells = rows * cols

        // 1. 地雷密度因子 (15% ~ 25% 為常態，>25% 顯著變難)
        let density = Double(totalMines) / Double(max(1, totalCells))
        let densityScore = Int(density * 180.0) // 例如 20% -> 36分

        // 2. 邊界活躍變數統計 (Frontier)
        var frontierCells = Set<String>()
        var maxVariablesInConstraint = 0
        var totalActiveConstraints = 0

        for r in 0..<rows {
            for c in 0..<cols {
                let cell = grid[r][c]
                if cell.isRevealed, let _ = cell.neighboringMines {
                    var hiddens = 0
                    for dr in -1...1 {
                        for dc in -1...1 {
                            if dr == 0 && dc == 0 { continue }
                            let nr = r + dr
                            let nc = c + dc
                            if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                                if grid[nr][nc].isHidden {
                                    frontierCells.insert("\(nr),\(nc)")
                                    hiddens += 1
                                }
                            }
                        }
                    }
                    if hiddens > 0 {
                        totalActiveConstraints += 1
                        if hiddens > maxVariablesInConstraint {
                            maxVariablesInConstraint = hiddens
                        }
                    }
                }
            }
        }

        // 3. 執行求解器檢測所需之最高階推理技巧
        let solver = SmartSolver.shared.analyze(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount)

        var techniques: [String] = []
        var reasoningScore = 0

        if !solver.sureSafeCells.isEmpty || !solver.sureMineCells.isEmpty {
            techniques.append("相鄰數字直接推導")
            reasoningScore += 10
        }

        if solver.status == .guessRequired {
            techniques.append("死局機率抉擇 (Guessing)")
            reasoningScore += 35
        } else if !solver.sureSafeCells.isEmpty {
            techniques.append("CSP 約束枚舉驗證")
            reasoningScore += 20
        }

        if maxVariablesInConstraint >= 5 {
            techniques.append("高階多格連鎖")
            reasoningScore += 15
        }

        // 4. 綜合加權評分 (1~100)
        let frontierScore = min(25, frontierCells.count * 2)
        let rawScore = densityScore + frontierScore + reasoningScore
        let finalScore = max(1, min(100, rawScore))

        let tier: DifficultyTier
        switch finalScore {
        case 1...25: tier = .beginner
        case 26...50: tier = .intermediate
        case 51...75: tier = .advanced
        case 76...90: tier = .expert
        default: tier = .master
        }

        let summary = "演算法評估本局難度指數為 \(finalScore) 分 (\(tier.rawValue))，包含 \(techniques.joined(separator: "、"))。"

        return DifficultyRatingReport(
            score: finalScore,
            tier: tier,
            frontierSize: frontierCells.count,
            maxConstraintVariables: maxVariablesInConstraint,
            techniquesRequired: techniques,
            summary: summary
        )
    }
}
