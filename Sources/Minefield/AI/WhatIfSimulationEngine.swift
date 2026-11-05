import Foundation

/// 假設推論類型
public enum HypothesisType: String, CaseIterable, Sendable {
    case assumeSafe = "假設為安全格"
    case assumeMine = "假設為地雷格"
}

/// 假設推論模擬情境分析結果
public struct SimulationScenario: Equatable, Sendable {
    public let target: GridCoordinate
    public let hypothesis: HypothesisType
    public let resultingSolverResult: SolverResult
    public let newlyDeducedSafe: [GridCoordinate]
    public let newlyDeducedMines: [GridCoordinate]
    public let hasContradiction: Bool
    public let contradictionReason: String?
    public let pedagogicalSummary: String

    public init(
        target: GridCoordinate,
        hypothesis: HypothesisType,
        resultingSolverResult: SolverResult,
        newlyDeducedSafe: [GridCoordinate],
        newlyDeducedMines: [GridCoordinate],
        hasContradiction: Bool,
        contradictionReason: String?,
        pedagogicalSummary: String
    ) {
        self.target = target
        self.hypothesis = hypothesis
        self.resultingSolverResult = resultingSolverResult
        self.newlyDeducedSafe = newlyDeducedSafe
        self.newlyDeducedMines = newlyDeducedMines
        self.hasContradiction = hasContradiction
        self.contradictionReason = contradictionReason
        self.pedagogicalSummary = pedagogicalSummary
    }
}

/// What-if 假設棋局實驗室引擎 (完全隔離於 SimulationContext，絕不修改真正遊戲盤面)
public final class WhatIfSimulationEngine: Sendable {
    public static let shared = WhatIfSimulationEngine()

    public init() {}

    /// 執行假設分析
    public func simulate(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int,
        target: GridCoordinate,
        hypothesis: HypothesisType
    ) -> SimulationScenario {
        let rows = grid.count
        guard rows > 0 else {
            return emptyScenario(target: target, hypothesis: hypothesis)
        }
        let cols = grid[0].count

        guard target.row >= 0 && target.row < rows && target.column >= 0 && target.column < cols else {
            return emptyScenario(target: target, hypothesis: hypothesis)
        }

        guard grid[target.row][target.column].isHidden else {
            return SimulationScenario(
                target: target,
                hypothesis: hypothesis,
                resultingSolverResult: .empty(),
                newlyDeducedSafe: [],
                newlyDeducedMines: [],
                hasContradiction: false,
                contradictionReason: nil,
                pedagogicalSummary: "座標 (\(target.row), \(target.column)) 已經翻開或插旗，無需假設。"
            )
        }

        // 基準分析
        let baseline = SmartSolver.shared.analyze(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount)
        let baselineSafe = Set(baseline.sureSafeCells.map { "\($0.row),\($0.column)" })
        let baselineMines = Set(baseline.sureMineCells.map { "\($0.row),\($0.column)" })

        // 建立獨立的模擬網格複本
        var simGrid = grid

        if hypothesis == .assumeMine {
            // 假設為雷：模擬插旗
            simGrid[target.row][target.column] = PublicCell(
                row: target.row,
                column: target.column,
                state: .flagged,
                neighboringMines: nil
            )

            // 檢查是否直接違反周圍數字約束 (例如相鄰已插旗數超過數字)
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = target.row + dr
                    let nc = target.column + dc
                    if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                        let neighbor = simGrid[nr][nc]
                        if neighbor.isRevealed, let required = neighbor.neighboringMines {
                            var flags = 0
                            for ddr in -1...1 {
                                for ddc in -1...1 {
                                    if ddr == 0 && ddc == 0 { continue }
                                    let nnr = nr + ddr
                                    let nnc = nc + ddc
                                    if nnr >= 0 && nnr < rows && nnc >= 0 && nnc < cols {
                                        if simGrid[nnr][nnc].isFlagged { flags += 1 }
                                    }
                                }
                            }
                            if flags > required {
                                return SimulationScenario(
                                    target: target,
                                    hypothesis: hypothesis,
                                    resultingSolverResult: baseline,
                                    newlyDeducedSafe: [target],
                                    newlyDeducedMines: [],
                                    hasContradiction: true,
                                    contradictionReason: "座標 (\(target.row), \(target.column)) 若為地雷，將導致數字格 (\(nr), \(nc)) 周圍地雷數 (\(flags)) 超出標示上限 (\(required))！",
                                    pedagogicalSummary: "💥 產生數學矛盾：此格必不可能為雷，因此經反證法證明此格為【必然安全】！"
                                )
                            }
                        }
                    }
                }
            }

            // 重新運行求解器評估連鎖推導
            let simSolver = SmartSolver.shared.analyze(
                grid: simGrid,
                totalMines: totalMines,
                flaggedCount: flaggedCount + 1
            )

            let newlySafe = simSolver.sureSafeCells.filter { !baselineSafe.contains("\($0.row),\($0.column)") }
            let newlyMines = simSolver.sureMineCells.filter { !baselineMines.contains("\($0.row),\($0.column)") }

            let summary = "假設 (\(target.row), \(target.column)) 為地雷：若此假設成立，後續將直接解鎖 \(newlySafe.count) 個安全格，並確定 \(newlyMines.count) 顆額外地雷。"

            return SimulationScenario(
                target: target,
                hypothesis: hypothesis,
                resultingSolverResult: simSolver,
                newlyDeducedSafe: newlySafe,
                newlyDeducedMines: newlyMines,
                hasContradiction: false,
                contradictionReason: nil,
                pedagogicalSummary: summary
            )

        } else {
            // 假設為安全格：檢查周圍數字是否有剩餘未知格不足以滿足地雷需求之矛盾
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = target.row + dr
                    let nc = target.column + dc
                    if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                        let neighbor = simGrid[nr][nc]
                        if neighbor.isRevealed, let required = neighbor.neighboringMines {
                            var flags = 0
                            var hiddens = 0
                            for ddr in -1...1 {
                                for ddc in -1...1 {
                                    if ddr == 0 && ddc == 0 { continue }
                                    let nnr = nr + ddr
                                    let nnc = nc + ddc
                                    if nnr >= 0 && nnr < rows && nnc >= 0 && nnc < cols {
                                        if nnr == target.row && nnc == target.column {
                                            // 假設 target 為安全格，不計入雷
                                        } else if simGrid[nnr][nnc].isFlagged {
                                            flags += 1
                                        } else if simGrid[nnr][nnc].isHidden {
                                            hiddens += 1
                                        }
                                    }
                                }
                            }
                            if flags + hiddens < required {
                                return SimulationScenario(
                                    target: target,
                                    hypothesis: hypothesis,
                                    resultingSolverResult: baseline,
                                    newlyDeducedSafe: [],
                                    newlyDeducedMines: [target],
                                    hasContradiction: true,
                                    contradictionReason: "座標 (\(target.row), \(target.column)) 若為安全格，數字格 (\(nr), \(nc)) 周遭剩餘候選格 (\(flags + hiddens)) 將不足以湊齊所需地雷 (\(required))！",
                                    pedagogicalSummary: "💥 產生數學矛盾：此格必不可能為安全格，因此經反證法證明此格為【必然地雷】！"
                                )
                            }
                        }
                    }
                }
            }

            let summary = "假設 (\(target.row), \(target.column)) 為安全格：暫時未引發直接約束衝突。在無雷假設下，該區域的緊張度降低。"

            return SimulationScenario(
                target: target,
                hypothesis: hypothesis,
                resultingSolverResult: baseline,
                newlyDeducedSafe: [],
                newlyDeducedMines: [],
                hasContradiction: false,
                contradictionReason: nil,
                pedagogicalSummary: summary
            )
        }
    }

    private func emptyScenario(target: GridCoordinate, hypothesis: HypothesisType) -> SimulationScenario {
        SimulationScenario(
            target: target,
            hypothesis: hypothesis,
            resultingSolverResult: .empty(),
            newlyDeducedSafe: [],
            newlyDeducedMines: [],
            hasContradiction: false,
            contradictionReason: nil,
            pedagogicalSummary: "無效之假設分析標的。"
        )
    }
}
