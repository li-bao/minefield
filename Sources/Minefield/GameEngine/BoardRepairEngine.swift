import Foundation

/// 棋盤動態修復引擎 (純 Swift 交易式數學最佳化)
/// 嚴格遵循：不改變已揭露數字、不將地雷移至已翻開格、總雷數恆定、最小修改原則
public final class BoardRepairEngine: Sendable {
    public static let shared = BoardRepairEngine()

    private let solver: SolverProtocol

    public init(solver: SolverProtocol = SmartSolver.shared) {
        self.solver = solver
    }

    // MARK: - 主修復運算方法 (交易式防猜修復)

    /// 嘗試對目前陷入猜測局面的棋盤進行最小幅度修復
    /// - Parameters:
    ///   - board: 目前棋盤
    ///   - solverResult: 目前求解器結果 (必須為 GUESS_REQUIRED 才觸發)
    /// - Returns: 修復結果報告 (若成功則包含已驗證之全新 Board 實體)
    public func attemptRepair(
        board: Board,
        solverResult: SolverResult
    ) -> BoardRepairResult {
        // 1. 若非需要猜測之局盤，無須修復
        guard solverResult.status == .guessRequired || solverResult.sureSafeCells.isEmpty else {
            return .failure(reason: "目前棋盤已有必然安全解，無須執行防猜修復。")
        }

        // 2. 建立交易快照 (若驗證失敗立即回滾至此快照)
        let initialSnapshot = board

        let rows = board.rows
        let cols = board.columns
        let totalMines = board.totalMines

        // 收集已翻開格子與其原始數字
        var revealedCoords: [(row: Int, column: Int)] = []
        var originalNumbers: [String: Int] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = board[r, c]
                if cell.isRevealed {
                    revealedCoords.append((r, c))
                    originalNumbers["\(r),\(c)"] = cell.neighboringMines
                }
            }
        }

        // 收集所有未翻開之格子
        var hiddenMineCoords: [(row: Int, column: Int)] = []
        var hiddenEmptyCoords: [(row: Int, column: Int)] = []

        for r in 0..<rows {
            for c in 0..<cols {
                let cell = board[r, c]
                if cell.isHidden || cell.isFlagged {
                    if cell.hasMine {
                        hiddenMineCoords.append((r, c))
                    } else {
                        hiddenEmptyCoords.append((r, c))
                    }
                }
            }
        }

        guard !hiddenMineCoords.isEmpty && !hiddenEmptyCoords.isEmpty else {
            return .failure(reason: "棋盤未揭開之可用地雷或空格不足，無法重配。")
        }

        // 3. 計算每個未翻開格子的「已揭露足跡」 (Revealed Footprint)
        // Footprint(v) = neighbors(v) ∩ revealedCoords
        // 只要兩格 Footprint 完全一致，交換地雷絕不影響任何已翻開數字！
        func computeFootprint(row: Int, col: Int) -> Set<String> {
            var fp = Set<String>()
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = row + dr
                    let nc = col + dc
                    if board.isValidCoordinate(row: nr, column: nc) && board[nr, nc].isRevealed {
                        fp.insert("\(nr),\(nc)")
                    }
                }
            }
            return fp
        }

        var footprintGroups = [Set<String>: (mines: [(Int, Int)], empties: [(Int, Int)])]()

        for m in hiddenMineCoords {
            let fp = computeFootprint(row: m.row, col: m.column)
            var current = footprintGroups[fp] ?? ([], [])
            current.mines.append(m)
            footprintGroups[fp] = current
        }

        for e in hiddenEmptyCoords {
            let fp = computeFootprint(row: e.row, col: e.column)
            var current = footprintGroups[fp] ?? ([], [])
            current.empties.append(e)
            footprintGroups[fp] = current
        }

        // 4. 搜尋最小修改合法修復方案 (按 movedMines 數量由少至多排序)
        var bestPlan: (board: Board, moves: [MineMove], safeCells: [GridCoordinate])?

        // 策略 A: 單顆地雷等價足跡置換 (足跡相同者對調，影響 revealed 數字為 0)
        for (_, group) in footprintGroups {
            guard !group.mines.isEmpty && !group.empties.isEmpty else { continue }

            for m in group.mines {
                for e in group.empties {
                    var candidateBoard = initialSnapshot
                    // 移動地雷
                    candidateBoard[m.0, m.1].hasMine = false
                    candidateBoard[e.0, e.1].hasMine = true

                    // 重新計算全盤相鄰地雷數
                    recomputeNeighboringMines(board: &candidateBoard)

                    // 嚴格交易式驗證：所有已揭露格子數字必須 100% 保持原值
                    if verifyIntegrity(candidate: candidateBoard, originalNumbers: originalNumbers, totalMines: totalMines) {
                        let newSolverResult = solver.analyze(
                            grid: candidateBoard.toPublicGrid(),
                            totalMines: totalMines,
                            flaggedCount: candidateBoard.flaggedCount
                        )

                        // 驗證是否成功產生至少一個必然安全格！
                        if !newSolverResult.sureSafeCells.isEmpty {
                            let move = MineMove(from: GridCoordinate(m.0, m.1), to: GridCoordinate(e.0, e.1))
                            bestPlan = (candidateBoard, [move], newSolverResult.sureSafeCells)
                            break
                        }
                    }
                }
                if bestPlan != nil { break }
            }
            if bestPlan != nil { break }
        }

        // 策略 B: 雙地雷組合置換 (若策略 A 無法消除猜測)
        if bestPlan == nil {
            for (_, group) in footprintGroups {
                guard group.mines.count >= 2 && group.empties.count >= 2 else { continue }
                let m1 = group.mines[0], m2 = group.mines[1]
                let e1 = group.empties[0], e2 = group.empties[1]

                var candidateBoard = initialSnapshot
                candidateBoard[m1.0, m1.1].hasMine = false
                candidateBoard[m2.0, m2.1].hasMine = false
                candidateBoard[e1.0, e1.1].hasMine = true
                candidateBoard[e2.0, e2.1].hasMine = true

                recomputeNeighboringMines(board: &candidateBoard)

                if verifyIntegrity(candidate: candidateBoard, originalNumbers: originalNumbers, totalMines: totalMines) {
                    let newSolverResult = solver.analyze(
                        grid: candidateBoard.toPublicGrid(),
                        totalMines: totalMines,
                        flaggedCount: candidateBoard.flaggedCount
                    )

                    if !newSolverResult.sureSafeCells.isEmpty {
                        let moves = [
                            MineMove(from: GridCoordinate(m1.0, m1.1), to: GridCoordinate(e1.0, e1.1)),
                            MineMove(from: GridCoordinate(m2.0, m2.1), to: GridCoordinate(e2.0, e2.1))
                        ]
                        bestPlan = (candidateBoard, moves, newSolverResult.sureSafeCells)
                        break
                    }
                }
            }
        }

        // 5. 交易提交或回滾
        if let plan = bestPlan {
            // 成功：產生修復前後風險對比
            let riskBefore = solverResult.probabilities.mapValues { $0.mineProbability }
            let afterResult = solver.analyze(
                grid: plan.board.toPublicGrid(),
                totalMines: totalMines,
                flaggedCount: plan.board.flaggedCount
            )
            let riskAfter = afterResult.probabilities.mapValues { $0.mineProbability }

            let notes: [String] = [
                "已驗證：所有已翻開之 \(revealedCoords.count) 個格子周圍數字 100% 保持不變。",
                "已驗證：總地雷數量保持 \(totalMines) 顆不變。",
                "已驗證：未將任何地雷移入已揭露格中。",
                "成功解開猜測死局，新增 \(plan.safeCells.count) 個必然安全步！"
            ]

            return BoardRepairResult(
                success: true,
                movedMinesCount: plan.moves.count,
                moves: plan.moves,
                newSafeCells: plan.safeCells,
                repairedBoard: plan.board,
                riskBefore: riskBefore,
                riskAfter: riskAfter,
                validationNotes: notes,
                errorMessage: nil
            )
        } else {
            // 失敗：自動回滾，並明確回報原因
            return .failure(reason: "在嚴格保證既有 \(revealedCoords.count) 個已揭露數字不變與總雷數恆定之前提下，目前死局為拓撲封閉對稱，無法透過微調消除。")
        }
    }

    // MARK: - 驗證 AI 提出的外部修復方案 (交易式安全審查)

    public func validateAndApplyAIRepair(
        currentBoard: Board,
        aiPlan: RawAIRepairResponse
    ) -> BoardRepairResult {
        let initialSnapshot = currentBoard
        var candidateBoard = initialSnapshot
        let totalMines = currentBoard.totalMines

        var originalNumbers: [String: Int] = [:]
        for r in 0..<currentBoard.rows {
            for c in 0..<currentBoard.columns {
                if currentBoard[r, c].isRevealed {
                    originalNumbers["\(r),\(c)"] = currentBoard[r, c].neighboringMines
                }
            }
        }

        var validMoves: [MineMove] = []

        // 逐步套用 AI 建議並檢驗
        for sug in aiPlan.suggestions {
            let fromCoord = GridCoordinate(sug.fromRow, sug.fromCol)
            let toCoord = GridCoordinate(sug.toRow, sug.toCol)

            // 邊界檢查
            guard candidateBoard.isValidCoordinate(row: fromCoord.row, column: fromCoord.column) &&
                  candidateBoard.isValidCoordinate(row: toCoord.row, column: toCoord.column) else {
                return .failure(reason: "AI 建議的座標越界 (\(fromCoord.id) -> \(toCoord.id))。")
            }

            // 狀態檢查 (不能在已翻開格操作)
            guard !candidateBoard[fromCoord.row, fromCoord.column].isRevealed &&
                  !candidateBoard[toCoord.row, toCoord.column].isRevealed else {
                return .failure(reason: "AI 企圖對已翻開的格子放置或移除地雷。")
            }

            // 地雷真實狀態檢查
            guard candidateBoard[fromCoord.row, fromCoord.column].hasMine else {
                return .failure(reason: "AI 建議移除地雷之來源格 (\(fromCoord.id)) 原本並無地雷。")
            }
            guard !candidateBoard[toCoord.row, toCoord.column].hasMine else {
                return .failure(reason: "AI 建議放置地雷之目標格 (\(toCoord.id)) 已經存在地雷。")
            }

            candidateBoard[fromCoord.row, fromCoord.column].hasMine = false
            candidateBoard[toCoord.row, toCoord.column].hasMine = true
            validMoves.append(MineMove(from: fromCoord, to: toCoord))
        }

        recomputeNeighboringMines(board: &candidateBoard)

        // 驗證完整性
        guard verifyIntegrity(candidate: candidateBoard, originalNumbers: originalNumbers, totalMines: totalMines) else {
            return .failure(reason: "AI 提出之方案會破壞目前已揭露數字之真實意義，已被程式防護層拒絕並回滾。")
        }

        // 驗證是否真的消除了猜測
        let newSolverResult = solver.analyze(
            grid: candidateBoard.toPublicGrid(),
            totalMines: totalMines,
            flaggedCount: candidateBoard.flaggedCount
        )

        guard !newSolverResult.sureSafeCells.isEmpty else {
            return .failure(reason: "AI 提出的修復方案未能創造出必然安全格，仍存在猜測風險。")
        }

        return BoardRepairResult(
            success: true,
            movedMinesCount: validMoves.count,
            moves: validMoves,
            newSafeCells: newSolverResult.sureSafeCells,
            repairedBoard: candidateBoard,
            validationNotes: ["AI 建議通過嚴格數學審查，所有已知數字與限制完整保留。"],
            errorMessage: nil
        )
    }

    // MARK: - 輔助方法

    private func recomputeNeighboringMines(board: inout Board) {
        let rows = board.rows
        let cols = board.columns
        for r in 0..<rows {
            for c in 0..<cols {
                if board[r, c].hasMine {
                    board[r, c].neighboringMines = 0
                } else {
                    var count = 0
                    for dr in -1...1 {
                        for dc in -1...1 {
                            if dr == 0 && dc == 0 { continue }
                            let nr = r + dr
                            let nc = c + dc
                            if board.isValidCoordinate(row: nr, column: nc) && board[nr, nc].hasMine {
                                count += 1
                            }
                        }
                    }
                    board[r, c].neighboringMines = count
                }
            }
        }
    }

    private func verifyIntegrity(
        candidate: Board,
        originalNumbers: [String: Int],
        totalMines: Int
    ) -> Bool {
        // 1. 驗證總雷數守恆
        var actualMines = 0
        for r in 0..<candidate.rows {
            for c in 0..<candidate.columns {
                if candidate[r, c].hasMine {
                    actualMines += 1
                    // 2. 驗證已翻開格不可有雷
                    if candidate[r, c].isRevealed {
                        return false
                    }
                }
            }
        }
        guard actualMines == totalMines else {
            return false
        }

        // 3. 驗證所有已揭露格子鄰近地雷數 100% 吻合
        for (coordKey, origNum) in originalNumbers {
            let parts = coordKey.split(separator: ",").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            let r = parts[0], c = parts[1]
            if candidate[r, c].neighboringMines != origNum {
                return false
            }
        }

        return true
    }
}
