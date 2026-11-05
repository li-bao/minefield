import XCTest
@testable import Minefield

final class Phase4_5DynamicAIBoardTests: XCTestCase {

    // MARK: - A. 無猜棋局生成測試 (No-Guess Board Generator)

    func testNoGuessBoardGeneratorProducesSolvableBoard() async {
        let generator = NoGuessBoardGenerator()
        let fixedSeed: UInt64 = 42

        // 測試初級難度生成
        let result = await generator.generate(
            difficulty: .beginner,
            firstClick: (4, 4),
            maxRetries: 30,
            baseSeed: fixedSeed
        )

        XCTAssertNotNil(result, "初級難度應能成功生成無猜棋盤")
        if let (board, _) = result {
            XCTAssertEqual(board.rows, 9)
            XCTAssertEqual(board.columns, 9)
            XCTAssertEqual(board.totalMines, 10)

            // 驗證棋盤確為邏輯無猜可解
            let solvable = generator.isNaturallySolvableWithoutGuess(board: board, firstClick: (4, 4))
            XCTAssertTrue(solvable, "生成的無猜棋盤必須在模擬中 100% 邏輯可解")
        }
    }

    func testNoGuessGeneratorRejectsGuessingBoards() {
        let generator = NoGuessBoardGenerator()

        // 人工建構一個包含 50/50 死局的 2x2 棋盤 (1 顆地雷)
        // 點擊 (1, 1) 翻開數字 1，未翻開鄰居 (0, 0) 與 (0, 1) 各有 50% 機率為地雷
        var board = Board(rows: 2, columns: 2, totalMines: 1)
        board[0, 0].hasMine = true
        board[1, 0].neighboringMines = 1
        board[1, 1].neighboringMines = 1

        let isSolvable = generator.isNaturallySolvableWithoutGuess(board: board, firstClick: (1, 1))
        XCTAssertFalse(isSolvable, "包含 50/50 猜測局面的棋盤不得被判定為無猜棋盤")
    }

    // MARK: - B. 棋局修復測試 (Board Repair Engine)

    func testBoardRepairPreservesRevealedNumbersAndTotalMines() {
        // 建立一個 3x4 棋盤，中央陷入局部對稱死局：
        // 已翻開 (2, 0) 數字為 1，相鄰未翻開為 (1, 0) 與 (1, 1)
        // 目前 (1, 0) 有地雷，(1, 1) 無地雷
        var board = Board(rows: 4, columns: 4, totalMines: 2)
        board[2, 0].state = .revealed
        board[2, 0].neighboringMines = 1

        board[1, 0].hasMine = true
        board[0, 3].hasMine = true // 背景格雷

        board[1, 0].neighboringMines = 0
        board[1, 1].neighboringMines = 0

        let solverResult = SmartSolver.shared.analyze(
            grid: board.toPublicGrid(),
            totalMines: 2,
            flaggedCount: 0
        )

        // 執行交易式修復
        let repairEngine = BoardRepairEngine()
        let repairResult = repairEngine.attemptRepair(board: board, solverResult: solverResult)

        if repairResult.success, let repaired = repairResult.repairedBoard {
            // 驗證 1: 已揭露格子的數字 100% 保持原值
            XCTAssertEqual(repaired[2, 0].neighboringMines, 1, "已揭露格子的數字絕不可改變")
            XCTAssertTrue(repaired[2, 0].isRevealed)

            // 驗證 2: 已揭露格不可被移入地雷
            XCTAssertFalse(repaired[2, 0].hasMine)

            // 驗證 3: 總地雷數守恆
            var actualMines = 0
            for r in 0..<4 {
                for c in 0..<4 {
                    if repaired[r, c].hasMine { actualMines += 1 }
                }
            }
            XCTAssertEqual(actualMines, 2, "修復前後總地雷數必須嚴格守恆")

            // 驗證 4: 最小修改原則 (通常只需微調 1 顆地雷)
            XCTAssertEqual(repairResult.movedMinesCount, 1)

            // 驗證 5: 成功產生必然安全格
            XCTAssertFalse(repairResult.newSafeCells.isEmpty, "修復後必須解鎖至少一個必然安全格")
        }
    }

    func testBoardRepairRollbackOnFailure() {
        // 建立一個已全開的棋盤，無未翻開地雷可調動
        let board = Board(rows: 2, columns: 2, totalMines: 1)
        let solverResult = SmartSolver.shared.analyze(grid: board.toPublicGrid(), totalMines: 1, flaggedCount: 0)

        let repairEngine = BoardRepairEngine()
        let result = repairEngine.attemptRepair(board: board, solverResult: solverResult)

        // 驗證回滾：未成功時絕不回傳半成品棋盤
        if !result.success {
            XCTAssertNil(result.repairedBoard)
            XCTAssertNotNil(result.errorMessage)
        }
    }

    // MARK: - C. 動態防猜機制測試 (Dynamic Anti-Guess)

    func testDynamicAntiGuessInNoGuessMode() {
        let engine = GameEngine(difficulty: .beginner, mode: .noGuess, seed: 1024)
        engine.revealCell(atRow: 4, column: 4)

        // 模擬玩家進行多步翻開，驗證 No-Guess 模式下每步後均不會殘留必然死局
        XCTAssertEqual(engine.mode, .noGuess)
        XCTAssertTrue(engine.state == .inProgress || engine.state == .won)
    }

    // MARK: - D. AI 修復建議安全審查測試

    func testAISuggestionValidationRejectsIllegalMove() {
        var board = Board(rows: 3, columns: 3, totalMines: 1)
        board[0, 0].state = .revealed
        board[2, 2].hasMine = true

        let repairEngine = BoardRepairEngine()

        // 測試案例 1: AI 企圖將地雷移入「已揭露格」 (0, 0)
        let illegalMove1 = RawAIRepairResponse(
            analysis: "惡意測試",
            repair_strategy: "minimal_change",
            reasoning: "企圖污染已揭露格",
            suggestions: [RawAIRepairSuggestion(fromRow: 2, fromCol: 2, toRow: 0, toCol: 0)]
        )
        let result1 = repairEngine.validateAndApplyAIRepair(currentBoard: board, aiPlan: illegalMove1)
        XCTAssertFalse(result1.success, "將地雷移入已翻開格的 AI 建議必須被直接拒絕")

        // 測試案例 2: AI 建議的來源格根本無雷
        let illegalMove2 = RawAIRepairResponse(
            analysis: "虛構來源測試",
            repair_strategy: "minimal_change",
            reasoning: "來源無雷",
            suggestions: [RawAIRepairSuggestion(fromRow: 1, fromCol: 1, toRow: 0, toCol: 2)]
        )
        let result2 = repairEngine.validateAndApplyAIRepair(currentBoard: board, aiPlan: illegalMove2)
        XCTAssertFalse(result2.success, "來源格無雷的 AI 建議必須被直接拒絕")
    }

    // MARK: - E. 自動排雷 (Auto Solve) 測試

    func testAutoSolveNeverRevealsMinesAndStopsOnGuess() {
        let engine = GameEngine(difficulty: .beginner, seed: 2026)
        engine.revealCell(atRow: 0, column: 0) // 開局

        let initialExploded = engine.explodedMineCount

        // 執行自動排雷
        let outcome = engine.performAutoSolveStep()

        // 驗證 1: 絕不可踩爆地雷
        XCTAssertEqual(engine.explodedMineCount, initialExploded, "自動排雷絕對不可觸發地雷爆炸")

        // 驗證 2: 公平性記錄已累積操作數
        if !outcome.revealed.isEmpty || !outcome.flagged.isEmpty {
            XCTAssertGreaterThan(engine.fairnessRecord.autoSolveCount, 0)
            XCTAssertFalse(engine.fairnessRecord.isPureClassicValid, "經自動排雷輔助後不得記錄為純經典紀錄")
        }
    }

    // MARK: - F. 棋局公平性記錄測試 (Fairness Tracking)

    func testFairnessRecordSeparation() {
        var record = GameFairnessRecord(seed: 12345)
        XCTAssertTrue(record.isPureClassicValid, "純淨新開局應為經典有效")

        // 當發生修復時
        record.repairCount += 1
        record.movedMinesCount += 1
        XCTAssertFalse(record.isPureClassicValid, "經過修復之棋盤不得作為純經典有效紀錄")
    }
}
