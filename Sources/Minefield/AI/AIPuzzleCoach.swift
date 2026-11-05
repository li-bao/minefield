import Foundation

/// 教學層級
public enum CoachLevel: String, CaseIterable, Sendable {
    case beginner = "初學者 (Level 1: 基礎相鄰與插旗)"
    case intermediate = "進階玩家 (Level 2: 數字差值與集合推理)"
    case expert = "專家級 (Level 3: CSP 回溯與全域機率)"
}

/// 候選格風險比較項目
public struct CandidateRiskComparison: Identifiable, Equatable, Sendable {
    public var id: String { "\(coordinate.row),\(coordinate.column)" }
    public let coordinate: GridCoordinate
    public let riskPercentage: Double
    public let evaluationNote: String

    public init(coordinate: GridCoordinate, riskPercentage: Double, evaluationNote: String) {
        self.coordinate = coordinate
        self.riskPercentage = riskPercentage
        self.evaluationNote = evaluationNote
    }
}

/// AI 教練的逐步教學報告
public struct CoachLesson: Equatable, Sendable {
    public let level: CoachLevel
    public let title: String
    public let strategyName: String
    public let mathematicalConditions: [String]
    public let stepByStepExplanation: [String]
    public let focusCells: [GridCoordinate]
    public let candidateComparisons: [CandidateRiskComparison]
    public let isGuessRequired: Bool
    public let conclusion: String
    public let isVerifiedBySolver: Bool

    public init(
        level: CoachLevel,
        title: String,
        strategyName: String,
        mathematicalConditions: [String],
        stepByStepExplanation: [String],
        focusCells: [GridCoordinate],
        candidateComparisons: [CandidateRiskComparison],
        isGuessRequired: Bool,
        conclusion: String,
        isVerifiedBySolver: Bool
    ) {
        self.level = level
        self.title = title
        self.strategyName = strategyName
        self.mathematicalConditions = mathematicalConditions
        self.stepByStepExplanation = stepByStepExplanation
        self.focusCells = focusCells
        self.candidateComparisons = candidateComparisons
        self.isGuessRequired = isGuessRequired
        self.conclusion = conclusion
        self.isVerifiedBySolver = isVerifiedBySolver
    }
}

/// AI 智慧排雷解題教練 (AI Puzzle Coach)
public final class AIPuzzleCoach: Sendable {
    public static let shared = AIPuzzleCoach()

    public init() {}

    /// 根據公開盤面分析並產生專屬分級教學
    public func generateLesson(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int,
        level: CoachLevel = .intermediate
    ) -> CoachLesson {
        let solverResult = SmartSolver.shared.analyze(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount)

        switch solverResult.status {
        case .safe:
            return buildSafeCellLesson(solverResult: solverResult, level: level)
        case .mine:
            return buildMineCellLesson(solverResult: solverResult, level: level)
        case .guessRequired:
            return buildGuessRequiredLesson(solverResult: solverResult, level: level, totalMines: totalMines, flaggedCount: flaggedCount)
        case .incomplete:
            return CoachLesson(
                level: level,
                title: "搜尋資源上限提醒",
                strategyName: "啟發式分群近似",
                mathematicalConditions: ["搜尋節點達到上限 (20,000)，CSP 無法窮舉所有連通分支配置。"],
                stepByStepExplanation: [
                    "當前未知邊界過大，組合空間呈現指數級膨脹。",
                    "求解器承認不確定性，不將不完整搜尋結果當作確定結論。",
                    "建議先從周圍已知機率最小的邊界切入。"
                ],
                focusCells: solverResult.lowestRiskCells.prefix(3).map { GridCoordinate($0.row, $0.column) },
                candidateComparisons: solverResult.lowestRiskCells.prefix(3).map {
                    CandidateRiskComparison(
                        coordinate: GridCoordinate($0.row, $0.column),
                        riskPercentage: $0.risk * 100.0,
                        evaluationNote: "邊界近似估計風險 \(Int($0.risk * 100))%"
                    )
                },
                isGuessRequired: true,
                conclusion: "因計算限制目前無法 100% 確定安全格，請審慎評估最低風險候選格。",
                isVerifiedBySolver: false
            )
        case .noMovesPossible:
            return CoachLesson(
                level: level,
                title: "盤面無分析標的",
                strategyName: "無",
                mathematicalConditions: [],
                stepByStepExplanation: ["目前棋局可能尚未開始，或所有格子已全數翻開。"],
                focusCells: [],
                candidateComparisons: [],
                isGuessRequired: false,
                conclusion: "點擊任意未翻開方格開始遊戲。",
                isVerifiedBySolver: true
            )
        }
    }

    // MARK: - 必然安全格教學建構
    private func buildSafeCellLesson(solverResult: SolverResult, level: CoachLevel) -> CoachLesson {
        guard let target = solverResult.sureSafeCells.first else {
            return fallbackLesson(solverResult: solverResult, level: level)
        }

        switch level {
        case .beginner:
            return CoachLesson(
                level: .beginner,
                title: "【初學者技巧】安全格判定",
                strategyName: "相鄰數字與已滿足約束",
                mathematicalConditions: [
                    "若某數字周圍的插旗數已經等於該格數字：FlaggedCount == Number",
                    "則剩餘所有相鄰未翻開格子必定沒有地雷：HiddenNeighbors == 0 Mines"
                ],
                stepByStepExplanation: [
                    "步驟 1：觀察目標格 (\(target.row), \(target.column)) 鄰近的已揭露數字。",
                    "步驟 2：計算該數字四周已經插旗的地雷數量。",
                    "步驟 3：確認所需地雷已被完全標齊，因此其餘未知格均為安全格！"
                ],
                focusCells: [target],
                candidateComparisons: [
                    CandidateRiskComparison(coordinate: target, riskPercentage: 0.0, evaluationNote: "必然安全 (0% 風險)")
                ],
                isGuessRequired: false,
                conclusion: "可以直接翻開座標 (\(target.row), \(target.column))。",
                isVerifiedBySolver: true
            )

        case .intermediate:
            return CoachLesson(
                level: .intermediate,
                title: "【進階技巧】集合包含與差集推理 (1-2-1 / 1-2 棋型)",
                strategyName: "約束子集相減 (Subset Reduction)",
                mathematicalConditions: [
                    "設約束 A 包含未知集合 S_A，地雷需求為 k_A",
                    "設約束 B 包含未知集合 S_B，地雷需求為 k_B",
                    "若 S_A ⊆ S_B，則差集 (S_B - S_A) 中之地雷數嚴格等於 k_B - k_A"
                ],
                stepByStepExplanation: [
                    "步驟 1：檢視數字相鄰重疊的兩個約束方程。",
                    "步驟 2：利用集合相減消除共享未知數。",
                    "步驟 3：推導出 (\(target.row), \(target.column)) 的地雷係數為 0，證明安全。"
                ],
                focusCells: [target],
                candidateComparisons: [
                    CandidateRiskComparison(coordinate: target, riskPercentage: 0.0, evaluationNote: "集合差集推導 0% 地雷")
                ],
                isGuessRequired: false,
                conclusion: "透過約束相減確定 (\(target.row), \(target.column)) 100% 安全。",
                isVerifiedBySolver: true
            )

        case .expert:
            return CoachLesson(
                level: .expert,
                title: "【專家級技巧】CSP 約束滿足與空間枚舉",
                strategyName: "連通區塊回溯枚舉 (Connected Component Backtracking)",
                mathematicalConditions: [
                    "將未知變數切分為獨立圖論連通區塊。",
                    "在全部合法二元配置空間 Ω 中統計 target = 1 的頻率。",
                    "P(target = 1) = |{ω ∈ Ω | ω(target) = 1}| / |Ω| == 0.0"
                ],
                stepByStepExplanation: [
                    "步驟 1：建立連通未知變數之二元布林矩陣。",
                    "步驟 2：使用剪枝 DFS 遍歷所有全局滿足解。",
                    "步驟 3：在所有合規組合中，座標 (\(target.row), \(target.column)) 出現雷的次數嚴格為 0。"
                ],
                focusCells: [target],
                candidateComparisons: [
                    CandidateRiskComparison(coordinate: target, riskPercentage: 0.0, evaluationNote: "全局合法排列無一為雷 (P = 0.0)")
                ],
                isGuessRequired: false,
                conclusion: "數學證明 (\(target.row), \(target.column)) 無任何地雷可能，安心翻開。",
                isVerifiedBySolver: true
            )
        }
    }

    // MARK: - 必然地雷格教學建構
    private func buildMineCellLesson(solverResult: SolverResult, level: CoachLevel) -> CoachLesson {
        guard let target = solverResult.sureMineCells.first else {
            return fallbackLesson(solverResult: solverResult, level: level)
        }

        return CoachLesson(
            level: level,
            title: "【排雷教學】必然地雷格鎖定",
            strategyName: "鴿籠原理與約束飽和 (Pigeonhole Saturation)",
            mathematicalConditions: [
                "數字格需滿足地雷數 N，相鄰剩餘未翻開格數量剛好等於 N",
                "RemainingHidden == RequiredMines => 每一格均必為地雷"
            ],
            stepByStepExplanation: [
                "步驟 1：檢視相鄰未翻開格數量。",
                "步驟 2：扣除已插旗數後，剩餘需找出的地雷數正好等於剩餘未翻開格數。",
                "步驟 3：無其他分配可能，座標 (\(target.row), \(target.column)) 必然是雷！"
            ],
            focusCells: [target],
            candidateComparisons: [
                CandidateRiskComparison(coordinate: target, riskPercentage: 100.0, evaluationNote: "100% 必然是地雷，建議插旗保護")
            ],
            isGuessRequired: false,
            conclusion: "座標 (\(target.row), \(target.column)) 必然為雷，請插旗標記。",
            isVerifiedBySolver: true
        )
    }

    // MARK: - 猜測局勢教學建構
    private func buildGuessRequiredLesson(
        solverResult: SolverResult,
        level: CoachLevel,
        totalMines: Int,
        flaggedCount: Int
    ) -> CoachLesson {
        let comparisons = solverResult.lowestRiskCells.map { cand in
            CandidateRiskComparison(
                coordinate: GridCoordinate(cand.row, cand.column),
                riskPercentage: cand.risk * 100.0,
                evaluationNote: "客觀地雷機率 \(String(format: "%.1f", cand.risk * 100.0))%"
            )
        }

        let bestCandText: String
        if let best = solverResult.lowestRiskCells.first {
            bestCandText = " (\(best.row), \(best.column))"
        } else {
            bestCandText = ""
        }

        return CoachLesson(
            level: level,
            title: "【局面診斷】純邏輯死局 (GUESS_REQUIRED)",
            strategyName: "最小期望損失決策 (Minimum Risk Decision)",
            mathematicalConditions: [
                "當前公開約束之所有相容二元配置中，無任何格子機率為 0.0 或 1.0",
                "全域必然安全格子集 S_safe = ∅"
            ],
            stepByStepExplanation: [
                "步驟 1：求解器已完整窮舉當前盤面所有合法配置，證實無必然安全步。",
                "步驟 2：切勿盲目點擊！系統已比較所有候選邊界之客觀地雷機率。",
                "步驟 3：若必須嘗試，應優先選擇地雷機率最低的座標\(bestCandText)。"
            ],
            focusCells: comparisons.prefix(2).map { $0.coordinate },
            candidateComparisons: comparisons,
            isGuessRequired: true,
            conclusion: "目前無必然安全的下一步。可考慮點擊機率最低的候選格，或使用 AI 救援 / 棋盤修復。",
            isVerifiedBySolver: true
        )
    }

    private func fallbackLesson(solverResult: SolverResult, level: CoachLevel) -> CoachLesson {
        CoachLesson(
            level: level,
            title: "局勢分析",
            strategyName: "基礎排雷",
            mathematicalConditions: [],
            stepByStepExplanation: [solverResult.summary],
            focusCells: [],
            candidateComparisons: [],
            isGuessRequired: solverResult.status == .guessRequired,
            conclusion: solverResult.summary,
            isVerifiedBySolver: true
        )
    }
}
