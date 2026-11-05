import Foundation

/// 內建數學與命題邏輯約束滿足求解器 (Pure Swift CSP Engine)
/// 嚴格保證僅讀取 PublicCell，絕不探查底層機密雷區
public final class SmartSolver: SolverProtocol {
    public static let shared = SmartSolver()

    public let maxSearchNodes: Int
    public let maxConfigurationsPerComponent: Int

    public init(maxSearchNodes: Int = 20_000, maxConfigurationsPerComponent: Int = 5_000) {
        self.maxSearchNodes = maxSearchNodes
        self.maxConfigurationsPerComponent = maxConfigurationsPerComponent
    }

    // MARK: - 主分析進入點

    public func analyze(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int
    ) -> SolverResult {
        let rows = grid.count
        guard rows > 0 else { return .empty() }
        let cols = grid[0].count
        guard cols > 0 else { return .empty() }

        // 1. 建立初始約束條件 (依據已翻開數字格)
        var constraints = extractConstraints(from: grid, rows: rows, cols: cols)

        // 若無任何約束 (例如首發尚未點擊)
        if constraints.isEmpty {
            // 尋找任一未翻開格子
            var firstHidden: (Int, Int)?
            for r in 0..<rows {
                for c in 0..<cols {
                    if grid[r][c].isHidden {
                        firstHidden = (r, c)
                        break
                    }
                }
                if firstHidden != nil { break }
            }

            if let (hr, hc) = firstHidden {
                return SolverResult(
                    status: .safe,
                    probabilities: [:],
                    recommendedMove: CellRecommendation(
                        row: hr,
                        column: hc,
                        action: .reveal,
                        mineProbability: 0.0,
                        reason: "開局首步享有 3×3 禁雷保護，可安全點擊任一位置。"
                    ),
                    sureSafeCells: [GridCoordinate(hr, hc)],
                    sureMineCells: [],
                    lowestRiskCells: [],
                    isIncomplete: false,
                    summary: "開局首步享有安全區防護。"
                )
            } else {
                return .empty(summary: "盤面所有格子已翻開或標記完成。")
            }
        }

        // 2. 基礎邏輯與集合推理 (包含關係、子集相減、直接推導)
        var knownSafe = Set<String>()
        var knownMines = Set<String>()
        var deductionReasons = [String: String]()

        runDirectAndSubsetReduction(
            constraints: &constraints,
            knownSafe: &knownSafe,
            knownMines: &knownMines,
            reasons: &deductionReasons
        )

        // 3. 進階 CSP 求解 (連通區塊分割 + 回溯枚舉 + 機率統計)
        var cellProbabilities = [String: Double]()
        var isIncomplete = false

        // 先填入已由直接推導確定的格子
        for s in knownSafe { cellProbabilities[s] = 0.0 }
        for m in knownMines { cellProbabilities[m] = 1.0 }

        // 針對剩餘尚未完全確定的約束進行 CSP 分群回溯
        let activeConstraints = constraints.filter { !$0.variables.isEmpty && $0.requiredMines >= 0 }
        if !activeConstraints.isEmpty {
            let cspResult = solveCSPWithComponents(
                constraints: activeConstraints,
                alreadyDetermined: cellProbabilities
            )
            isIncomplete = cspResult.isIncomplete
            for (coord, prob) in cspResult.probabilities {
                cellProbabilities[coord] = prob
            }
        }

        // 4. 統計剩餘孤立格 (未與任何數字相鄰的未知格) 之背景機率
        let remainingKnownMines = totalMines - flaggedCount
        computeIsolatedCellsProbabilities(
            grid: grid,
            rows: rows,
            cols: cols,
            knownMinesCount: knownMines.count,
            remainingKnownMines: remainingKnownMines,
            cellProbabilities: &cellProbabilities
        )

        // 5. 整理結果並產生最佳建議
        return compileResult(
            cellProbabilities: cellProbabilities,
            reasons: deductionReasons,
            isIncomplete: isIncomplete
        )
    }

    // MARK: - 內部約束實體
    private struct Constraint: Equatable, Hashable {
        var variables: Set<String> // 格式 "row,col"
        var requiredMines: Int
        var sourceRow: Int
        var sourceCol: Int
        var sourceNumber: Int
    }

    // MARK: - 提取數字格約束
    private func extractConstraints(from grid: [[PublicCell]], rows: Int, cols: Int) -> [Constraint] {
        var list: [Constraint] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = grid[r][c]
                guard cell.isRevealed, let num = cell.neighboringMines else {
                    continue
                }

                // 統計相鄰未翻開與插旗格
                var hiddenCoords = Set<String>()
                var flagCount = 0

                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = r + dr
                        let nc = c + dc
                        guard nr >= 0 && nr < rows && nc >= 0 && nc < cols else { continue }
                        let neighbor = grid[nr][nc]
                        if neighbor.isFlagged {
                            flagCount += 1
                        } else if neighbor.isHidden {
                            hiddenCoords.insert("\(nr),\(nc)")
                        }
                    }
                }

                if !hiddenCoords.isEmpty {
                    let neededMines = max(0, num - flagCount)
                    list.append(Constraint(
                        variables: hiddenCoords,
                        requiredMines: neededMines,
                        sourceRow: r,
                        sourceCol: c,
                        sourceNumber: num
                    ))
                }
            }
        }
        return list
    }

    // MARK: - 基礎與集合包含推理 (Subset Reduction)
    private func runDirectAndSubsetReduction(
        constraints: inout [Constraint],
        knownSafe: inout Set<String>,
        knownMines: inout Set<String>,
        reasons: inout [String: String]
    ) {
        var changed = true
        var iteration = 0

        while changed && iteration < 30 {
            changed = false
            iteration += 1

            // 1. 單約束直接推導
            for c in constraints {
                if c.requiredMines == 0 && !c.variables.isEmpty {
                    for v in c.variables {
                        if !knownSafe.contains(v) {
                            knownSafe.insert(v)
                            reasons[v] = "數字 \(c.sourceNumber) (座標 \(c.sourceRow),\(c.sourceCol)) 周圍地雷已全數標記，此格必然安全。"
                            changed = true
                        }
                    }
                } else if c.requiredMines == c.variables.count && !c.variables.isEmpty {
                    for v in c.variables {
                        if !knownMines.contains(v) {
                            knownMines.insert(v)
                            reasons[v] = "數字 \(c.sourceNumber) (座標 \(c.sourceRow),\(c.sourceCol)) 剩餘空格數等於所需地雷數，此格必然為地雷。"
                            changed = true
                        }
                    }
                }
            }

            // 2. 將已知確定值代入其餘約束
            for i in 0..<constraints.count {
                let origVars = constraints[i].variables
                for safeVar in knownSafe {
                    if constraints[i].variables.contains(safeVar) {
                        constraints[i].variables.remove(safeVar)
                    }
                }
                for mineVar in knownMines {
                    if constraints[i].variables.contains(mineVar) {
                        constraints[i].variables.remove(mineVar)
                        constraints[i].requiredMines -= 1
                    }
                }
                if constraints[i].variables != origVars {
                    changed = true
                }
            }

            // 3. 集合包含關係推理 (Subset Deduction: S1 ⊆ S2)
            for i in 0..<constraints.count {
                for j in 0..<constraints.count {
                    if i == j { continue }
                    let c1 = constraints[i]
                    let c2 = constraints[j]

                    if !c1.variables.isEmpty && c1.variables.isSubset(of: c2.variables) {
                        let diffVars = c2.variables.subtracting(c1.variables)
                        let diffMines = c2.requiredMines - c1.requiredMines

                        if !diffVars.isEmpty && diffMines >= 0 {
                            if diffMines == 0 {
                                // 差集全為安全
                                for v in diffVars {
                                    if !knownSafe.contains(v) {
                                        knownSafe.insert(v)
                                        reasons[v] = "透過相鄰數字 (\(c2.sourceNumber) 與 \(c1.sourceNumber)) 之集合包含約束相減推導，此格必然安全。"
                                        changed = true
                                    }
                                }
                            } else if diffMines == diffVars.count {
                                // 差集全為地雷
                                for v in diffVars {
                                    if !knownMines.contains(v) {
                                        knownMines.insert(v)
                                        reasons[v] = "透過相鄰數字 (\(c2.sourceNumber) 與 \(c1.sourceNumber)) 之集合包含約束相減推導，此格必然為地雷。"
                                        changed = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - CSP 連通分群與回溯求解 (Connected Components + Backtracking)
    private struct CSPResult {
        var probabilities: [String: Double]
        var isIncomplete: Bool
    }

    private func solveCSPWithComponents(
        constraints: [Constraint],
        alreadyDetermined: [String: Double]
    ) -> CSPResult {
        // 收集所有尚未確定值的未知變數
        var activeVars = Set<String>()
        for c in constraints {
            for v in c.variables {
                if alreadyDetermined[v] == nil {
                    activeVars.insert(v)
                }
            }
        }

        guard !activeVars.isEmpty else {
            return CSPResult(probabilities: [:], isIncomplete: false)
        }

        // 依據約束共享關係建立圖並切割連通分量 (Connected Components)
        var adj = [String: Set<String>]()
        for v in activeVars { adj[v] = [] }

        for c in constraints {
            let vars = c.variables.filter { activeVars.contains($0) }
            for v1 in vars {
                for v2 in vars {
                    if v1 != v2 {
                        adj[v1]?.insert(v2)
                    }
                }
            }
        }

        var visited = Set<String>()
        var components: [Set<String>] = []

        for v in activeVars {
            if !visited.contains(v) {
                var comp = Set<String>()
                var q = [v]
                visited.insert(v)

                while !q.isEmpty {
                    let curr = q.removeFirst()
                    comp.insert(curr)
                    for n in adj[curr] ?? [] {
                        if !visited.contains(n) {
                            visited.insert(n)
                            q.append(n)
                        }
                    }
                }
                components.append(comp)
            }
        }

        var allProbabilities = [String: Double]()
        var overallIncomplete = false

        // 逐一對每個獨立連通分量進行 DFS 回溯求解
        for comp in components {
            let compVars = Array(comp)
            let compConstraints = constraints.filter { c in
                c.variables.contains(where: { comp.contains($0) })
            }

            let compResult = solveSingleComponent(
                variables: compVars,
                constraints: compConstraints
            )

            if compResult.isIncomplete {
                overallIncomplete = true
            }

            for (v, p) in compResult.probabilities {
                allProbabilities[v] = p
            }
        }

        return CSPResult(probabilities: allProbabilities, isIncomplete: overallIncomplete)
    }

    private func solveSingleComponent(
        variables: [String],
        constraints: [Constraint]
    ) -> CSPResult {
        var validConfigCount = 0
        var mineCounts = [String: Int]()
        for v in variables { mineCounts[v] = 0 }

        var currentAssignment = [String: Int]()
        var searchNodes = 0
        var isSearchAborted = false

        let maxNodes = self.maxSearchNodes
        let maxConfigs = self.maxConfigurationsPerComponent

        func backtrack(index: Int) {
            if isSearchAborted { return }
            searchNodes += 1
            if searchNodes > maxNodes {
                isSearchAborted = true
                return
            }

            // 邊界條件：全部變數配置完畢
            if index == variables.count {
                validConfigCount += 1
                for (v, val) in currentAssignment {
                    if val == 1 {
                        mineCounts[v, default: 0] += 1
                    }
                }
                if validConfigCount >= maxConfigs {
                    isSearchAborted = true
                }
                return
            }

            let currVar = variables[index]

            // 嘗試 0 (安全) 與 1 (地雷)
            for value in [0, 1] {
                currentAssignment[currVar] = value

                // 剪枝檢查：驗證目前所有約束是否依然可能合法
                var isFeasible = true
                for c in constraints {
                    var assignedSum = 0
                    var unassignedCount = 0

                    for v in c.variables {
                        if let assigned = currentAssignment[v] {
                            assignedSum += assigned
                        } else {
                            unassignedCount += 1
                        }
                    }

                    // 剪枝 1：當前已分配的地雷數已超過限制
                    if assignedSum > c.requiredMines {
                        isFeasible = false
                        break
                    }
                    // 剪枝 2：即使剩下未分配的全部填 1 也達不到所需地雷數
                    if assignedSum + unassignedCount < c.requiredMines {
                        isFeasible = false
                        break
                    }
                }

                if isFeasible {
                    backtrack(index: index + 1)
                }

                currentAssignment.removeValue(forKey: currVar)
            }
        }

        backtrack(index: 0)

        // 若搜尋因資源上限提前終止且未獲得任何合法解，標記不完整
        if isSearchAborted && validConfigCount == 0 {
            return CSPResult(probabilities: [:], isIncomplete: true)
        }

        var probabilities = [String: Double]()
        if validConfigCount > 0 {
            for v in variables {
                let count = mineCounts[v] ?? 0
                probabilities[v] = Double(count) / Double(validConfigCount)
            }
        }

        return CSPResult(probabilities: probabilities, isIncomplete: isSearchAborted)
    }

    // MARK: - 計算未接觸邊界的孤立格背景機率
    private func computeIsolatedCellsProbabilities(
        grid: [[PublicCell]],
        rows: Int,
        cols: Int,
        knownMinesCount: Int,
        remainingKnownMines: Int,
        cellProbabilities: inout [String: Double]
    ) {
        var isolatedHiddenCoords: [(Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let key = "\(r),\(c)"
                if grid[r][c].isHidden && cellProbabilities[key] == nil {
                    isolatedHiddenCoords.append((r, c))
                }
            }
        }

        guard !isolatedHiddenCoords.isEmpty else { return }

        // 估計孤立格子的地雷均勻分佈機率
        let totalAssignedFrontierMines = cellProbabilities.values.reduce(0.0, +)
        let unassignedMines = max(0.0, Double(remainingKnownMines) - totalAssignedFrontierMines)
        let uniformProb = min(1.0, max(0.01, unassignedMines / Double(isolatedHiddenCoords.count)))

        for (r, c) in isolatedHiddenCoords {
            cellProbabilities["\(r),\(c)"] = uniformProb
        }
    }

    // MARK: - 整理最終結果報告
    private func compileResult(
        cellProbabilities: [String: Double],
        reasons: [String: String],
        isIncomplete: Bool
    ) -> SolverResult {
        var probMap = [String: CellProbability]()
        var sureSafeList: [GridCoordinate] = []
        var sureMineList: [GridCoordinate] = []
        var uncertainList: [RiskCandidate] = []

        for (key, prob) in cellProbabilities {
            let parts = key.split(separator: ",").compactMap { Int($0) }
            guard parts.count == 2 else { continue }
            let r = parts[0]
            let c = parts[1]

            probMap[key] = CellProbability(row: r, column: c, mineProbability: prob)

            if abs(prob) < 1e-6 {
                sureSafeList.append(GridCoordinate(r, c))
            } else if abs(prob - 1.0) < 1e-6 {
                sureMineList.append(GridCoordinate(r, c))
            } else {
                uncertainList.append(RiskCandidate(row: r, column: c, risk: prob))
            }
        }

        // 依照風險由低到高排序候選猜測格
        uncertainList.sort { $0.risk < $1.risk }

        // 決策狀態與首選推薦 (安全 > 插旗 > 猜測最低風險)
        let status: SolverStatus
        let recommendedMove: CellRecommendation?
        let summaryText: String

        if !sureSafeList.isEmpty {
            status = .safe
            let topSafe = sureSafeList[0]
            let key = "\(topSafe.row),\(topSafe.column)"
            let reason = reasons[key] ?? "透過鄰近數字約束滿足求解 (CSP)，證明此格地雷機率為 0.0%，絕對安全。"
            recommendedMove = CellRecommendation(
                row: topSafe.row,
                column: topSafe.column,
                action: .reveal,
                mineProbability: 0.0,
                reason: reason
            )
            summaryText = "找到 \(sureSafeList.count) 個必然安全格！請優先翻開以推進盤面。"
        } else if !sureMineList.isEmpty {
            status = .mine
            let topMine = sureMineList[0]
            let key = "\(topMine.row),\(topMine.column)"
            let reason = reasons[key] ?? "透過鄰近數字約束滿足求解 (CSP)，證明此格地雷機率為 100.0%，必然為雷。"
            recommendedMove = CellRecommendation(
                row: topMine.row,
                column: topMine.column,
                action: .flag,
                mineProbability: 1.0,
                reason: reason
            )
            summaryText = "找到 \(sureMineList.count) 個必然地雷位置！建議立即插旗以釐清周圍格子。"
        } else if let bestGuess = uncertainList.first {
            if isIncomplete {
                status = .incomplete
                summaryText = "計算因搜尋資源上限提前停止，結論可能不完整。目前推算最低風險為 (\(bestGuess.row), \(bestGuess.column))。"
            } else {
                status = .guessRequired
                summaryText = "目前棋局需要猜測，無必然安全的下一步。已為您找出地雷風險最低之候選格。"
            }

            let riskPercent = String(format: "%.1f%%", bestGuess.risk * 100)
            recommendedMove = CellRecommendation(
                row: bestGuess.row,
                column: bestGuess.column,
                action: .guess,
                mineProbability: bestGuess.risk,
                reason: "經 CSP 遍歷所有合法排列，當前找不到確定安全位置。此格為全盤地雷風險最低之選項 (\(riskPercent) 地雷風險)。"
            )
        } else {
            status = .noMovesPossible
            recommendedMove = nil
            summaryText = "目前無可分析之未知格。"
        }

        return SolverResult(
            status: status,
            probabilities: probMap,
            recommendedMove: recommendedMove,
            sureSafeCells: sureSafeList,
            sureMineCells: sureMineList,
            lowestRiskCells: uncertainList,
            isIncomplete: isIncomplete,
            summary: summaryText
        )
    }
}
