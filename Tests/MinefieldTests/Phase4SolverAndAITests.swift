import XCTest
@testable import Minefield

final class Phase4SolverAndAITests: XCTestCase {

    // MARK: - 輔助方法：建立測試用的 PublicCell 網格
    private func createTestGrid(rows: Int, cols: Int, numbers: [String: Int], flags: Set<String> = []) -> [[PublicCell]] {
        var grid: [[PublicCell]] = []
        for r in 0..<rows {
            var rowList: [PublicCell] = []
            for c in 0..<cols {
                let key = "\(r),\(c)"
                if flags.contains(key) {
                    rowList.append(PublicCell(row: r, column: c, state: .flagged, neighboringMines: nil))
                } else if let num = numbers[key] {
                    rowList.append(PublicCell(row: r, column: c, state: .revealed, neighboringMines: num))
                } else {
                    rowList.append(PublicCell(row: r, column: c, state: .hidden, neighboringMines: nil))
                }
            }
            grid.append(rowList)
        }
        return grid
    }

    // MARK: - 1. 必然安全格推理測試
    func testGuaranteedSafeCellDiscovery() {
        // 建立情境：(0, 0) 為數字 1，周圍有 (0, 1) 已插旗，(1, 0) 為未知格
        // 因為旗幟數 (1) == 數字 (1)，因此 (1, 0) 必然安全！
        let grid = createTestGrid(
            rows: 3,
            cols: 3,
            numbers: ["0,0": 1],
            flags: ["0,1"]
        )

        let solver = SmartSolver()
        let result = solver.analyze(grid: grid, totalMines: 5, flaggedCount: 1)

        XCTAssertEqual(result.status, .safe)
        XCTAssertTrue(result.sureSafeCells.contains(GridCoordinate(1, 0)))
        XCTAssertEqual(result.probabilities["1,0"]?.mineProbability, 0.0)
    }

    // MARK: - 2. 必然地雷推理測試
    func testGuaranteedMineDiscovery() {
        // 建立情境：(0, 0) 為數字 1，只有一個未翻開鄰居 (0, 1)，無插旗
        // 因此 (0, 1) 必然是地雷！
        let grid = createTestGrid(
            rows: 2,
            cols: 2,
            numbers: ["0,0": 1, "1,0": 1, "1,1": 1],
            flags: []
        )
        // 此處 (0,1) 是唯一未翻開的格子，周圍三格皆為 1
        let solver = SmartSolver()
        let result = solver.analyze(grid: grid, totalMines: 1, flaggedCount: 0)

        XCTAssertEqual(result.status, .mine)
        XCTAssertTrue(result.sureMineCells.contains(GridCoordinate(0, 1)))
        XCTAssertEqual(result.probabilities["0,1"]?.mineProbability, 1.0)
        XCTAssertEqual(result.recommendedMove?.action, .flag)
    }

    // MARK: - 3. 集合包含與子集相減推理測試 (1-2-1 Pattern 等)
    func testSubsetDeductionInference() {
        // 經典 1-2 邊界格局：
        // (1, 1) 為 1，鄰居為 A(0, 1), B(0, 2)
        // (1, 2) 為 2，鄰居為 A(0, 1), B(0, 2), C(0, 3)
        // 約束 1: A + B = 1
        // 約束 2: A + B + C = 2
        // 由子集包含相減得: C = 2 - 1 = 1，故 C(0, 3) 必然是地雷！
        let grid = createTestGrid(
            rows: 3,
            cols: 5,
            numbers: [
                "1,1": 1,
                "1,2": 2,
                "2,1": 0,
                "2,2": 0,
                "2,3": 0
            ],
            flags: []
        )

        let solver = SmartSolver()
        let result = solver.analyze(grid: grid, totalMines: 5, flaggedCount: 0)

        // 驗證 CSP / 子集推導成功辨識必然地雷或安全
        XCTAssertTrue(result.sureMineCells.contains(GridCoordinate(0, 3)), "C(0,3) 應經由子集相減被判定為必然地雷")
    }

    // MARK: - 4. 辨識需要猜測之棋局 (50/50 死局) 與精確機率計算測試
    func testRecognizeGuessRequiredAndProbabilityAccuracy() {
        // 建立對稱 50/50 死局情境：
        // 格子 (1, 0) 為數字 1，其未揭開鄰居為 (0, 0) 與 (0, 1)
        // 兩格各有 1 顆地雷的可能性，完全對稱
        let grid = createTestGrid(
            rows: 2,
            cols: 2,
            numbers: ["1,0": 1, "1,1": 1],
            flags: []
        )

        let solver = SmartSolver()
        let result = solver.analyze(grid: grid, totalMines: 1, flaggedCount: 0)

        // 沒有必然安全解，應標記為需要猜測
        XCTAssertEqual(result.status, .guessRequired)
        XCTAssertTrue(result.sureSafeCells.isEmpty)
        XCTAssertTrue(result.sureMineCells.isEmpty)

        // 兩格機率應精確各為 50%
        let p1 = result.probabilities["0,0"]?.mineProbability ?? -1
        let p2 = result.probabilities["0,1"]?.mineProbability ?? -1
        XCTAssertEqual(p1, 0.5, accuracy: 1e-4)
        XCTAssertEqual(p2, 0.5, accuracy: 1e-4)
    }

    // MARK: - 5. 搜尋資源超過限制時回報不完整測試
    func testSearchResourceLimitReportsIncomplete() {
        let grid = createTestGrid(
            rows: 3,
            cols: 3,
            numbers: ["1,1": 2],
            flags: []
        )

        // 將 maxSearchNodes 設定為極小值 (1) 強制觸發搜尋上限
        let limitedSolver = SmartSolver(maxSearchNodes: 1, maxConfigurationsPerComponent: 1)
        let result = limitedSolver.analyze(grid: grid, totalMines: 2, flaggedCount: 0)

        XCTAssertTrue(result.isIncomplete, "當搜尋節點超過預算時，應明確標示 isIncomplete = true")
    }

    // MARK: - 6. AI 錯誤 JSON 容錯處理測試 (不崩潰)
    func testAICorruptedJSONHandling() {
        let aiEngine = AIEngine.shared
        let corruptedJSON = "{ invalid_json_here: true, "

        XCTAssertThrowsError(try aiEngine.parseRawAIResponse(corruptedJSON)) { error in
            guard let ollamaErr = error as? OllamaError, case .decodingFailed = ollamaErr else {
                XCTFail("應回傳 OllamaError.decodingFailed")
                return
            }
        }
    }

    // MARK: - 7. AI 建議非法位置 (越界、已翻開、已插旗) 嚴格拒絕測試
    func testAISafetyValidationRejectsIllegalSuggestions() {
        let grid = createTestGrid(
            rows: 3,
            cols: 3,
            numbers: ["1,1": 1],
            flags: ["0,0"]
        )

        let aiEngine = AIEngine.shared
        let solverResult = SmartSolver.shared.analyze(grid: grid, totalMines: 2, flaggedCount: 1)

        let illegalSuggestions: [RawAISuggestion] = [
            // 越界建議 (10, 10)
            RawAISuggestion(row: 10, column: 10, action: "reveal", reason: "AI 幻覺推薦越界格", confidence: 99),
            // 已插旗建議 (0, 0)
            RawAISuggestion(row: 0, column: 0, action: "reveal", reason: "AI 推薦已插旗格", confidence: 95),
            // 已翻開建議 (1, 1)
            RawAISuggestion(row: 1, column: 1, action: "reveal", reason: "AI 推薦已翻開格", confidence: 90)
        ]

        let validated = aiEngine.validateAISuggestions(
            rawSuggestions: illegalSuggestions,
            grid: grid,
            rows: 3,
            cols: 3,
            solverResult: solverResult
        )

        XCTAssertEqual(validated.count, 3)
        for sug in validated {
            XCTAssertEqual(sug.verificationStatus, .rejected, "非法建議必須被防護層標示為 .rejected")
            XCTAssertNotNil(sug.rejectionNote)
        }
    }

    // MARK: - 8. Ollama 斷線時內建 Solver 依然正常運作測試
    func testBuiltinSolverWorksIndependently() {
        let grid = createTestGrid(
            rows: 2,
            cols: 2,
            numbers: ["0,0": 0],
            flags: []
        )

        // 完全不連線 Ollama，直接執行 SmartSolver
        let solver = SmartSolver()
        let result = solver.analyze(grid: grid, totalMines: 1, flaggedCount: 0)

        // 數字 0 周圍所有格子均必然安全
        XCTAssertEqual(result.status, .safe)
        XCTAssertTrue(result.sureSafeCells.contains(GridCoordinate(0, 1)))
        XCTAssertTrue(result.sureSafeCells.contains(GridCoordinate(1, 0)))
        XCTAssertTrue(result.sureSafeCells.contains(GridCoordinate(1, 1)))
    }

    // MARK: - 9. 資訊隱藏安全驗證 (防作弊測試)
    func testInformationHidingGuaranteesNoCheating() {
        let engine = GameEngine(difficulty: .beginner, seed: 12345)
        engine.revealCell(atRow: 4, column: 4)

        let publicGrid = engine.publicBoard()

        // 驗證傳遞給 Solver 的 publicGrid 中，未翻開格子絕對無法得知 hasMine
        for row in publicGrid {
            for cell in row {
                if cell.isHidden || cell.isFlagged {
                    XCTAssertNil(cell.neighboringMines, "未翻開格子絕對不可提供鄰近地雷數")
                }
            }
        }
    }
}
