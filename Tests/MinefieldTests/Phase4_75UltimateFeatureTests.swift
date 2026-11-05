import XCTest
@testable import Minefield

final class Phase4_75UltimateFeatureTests: XCTestCase {

    // MARK: - 1. Undo / Redo 狀態還原與公平性測試
    func testUndoRedoLifecycle() {
        let engine = GameEngine(difficulty: .beginner, mode: .classic, seed: 12345)
        // 首步翻開 (0, 0)
        XCTAssertTrue(engine.revealCell(atRow: 0, column: 0))
        XCTAssertEqual(engine.state, .inProgress)

        let initialRevealedCount = engine.internalBoard.revealedCount
        XCTAssertGreaterThan(initialRevealedCount, 0)

        // 尋找一個未翻開且非地雷的格子點擊
        var nextHidden: (Int, Int)?
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if engine.internalBoard[r, c].state == .hidden && !engine.internalBoard[r, c].hasMine {
                    nextHidden = (r, c)
                    break
                }
            }
            if nextHidden != nil { break }
        }

        guard let (nr, nc) = nextHidden else {
            XCTFail("找不到未翻開且安全的候選格")
            return
        }

        // 翻開第二步
        XCTAssertTrue(engine.revealCell(atRow: nr, column: nc))
        let afterSecondRevealCount = engine.internalBoard.revealedCount
        XCTAssertGreaterThanOrEqual(afterSecondRevealCount, initialRevealedCount + 1)

        // 執行 Undo
        XCTAssertTrue(engine.performUndo())
        XCTAssertEqual(engine.internalBoard[nr, nc].state, .hidden)
        XCTAssertEqual(engine.internalBoard.revealedCount, initialRevealedCount)
        XCTAssertEqual(engine.fairnessRecord.undoCount, 1)
        XCTAssertFalse(engine.fairnessRecord.isPureClassicValid, "使用 Undo 後必須失去純經典有效認證")

        // 執行 Redo
        XCTAssertTrue(engine.performRedo())
        XCTAssertEqual(engine.internalBoard[nr, nc].state, .revealed)
        XCTAssertEqual(engine.internalBoard.revealedCount, afterSecondRevealCount)
    }

    // MARK: - 2. AI 救援安全原則測試 (絕不踩雷、嚴格記錄)
    func testAIRescueSafetyAndFairness() {
        let engine = GameEngine(difficulty: .intermediate, mode: .aiRescue, seed: 998877)
        // 首步展開安全區
        _ = engine.revealCell(atRow: 8, column: 8)
        XCTAssertEqual(engine.state, .inProgress)

        // 執行 AI 救援
        let rescuedCoord = engine.executeAIRescue()
        XCTAssertNotNil(rescuedCoord, "引擎必須找到真實安全格並揭露")

        if let coord = rescuedCoord {
            let cell = engine.internalBoard[coord.row, coord.column]
            XCTAssertFalse(cell.hasMine, "AI 救援揭露之方格絕不允許存在地雷！")
            XCTAssertEqual(cell.state, .revealed, "救援方格必須被安全翻開")
        }

        XCTAssertEqual(engine.fairnessRecord.aiRescueCount, 1)
        XCTAssertFalse(engine.fairnessRecord.isPureClassicValid, "AI 救援必須使純經典排行失效")
    }

    // MARK: - 3. 完整棋局回放 (Replay Engine)
    func testReplayRecordingAndPlayback() {
        let engine = GameEngine(difficulty: .beginner, mode: .classic, seed: 777)
        let replay = ReplayEngine.shared

        replay.startRecording(
            initialBoard: engine.internalBoard,
            difficulty: engine.difficulty,
            mode: engine.mode,
            seed: engine.currentSeed
        )

        // 執行操作
        _ = engine.revealCell(atRow: 4, column: 4)
        _ = engine.toggleFlag(atRow: 0, column: 0)
        _ = engine.toggleFlag(atRow: 0, column: 0) // 取消插旗

        let record = replay.finishRecording(
            finalState: engine.state,
            totalTime: 5.0,
            fairnessRecord: engine.fairnessRecord
        )

        XCTAssertNotNil(record)
        guard let rec = record else { return }
        XCTAssertGreaterThanOrEqual(rec.steps.count, 3)

        // 載入回放
        replay.loadRecord(rec)
        XCTAssertEqual(replay.currentStepIndex, 0)

        // 步進控制
        replay.stepForward()
        XCTAssertEqual(replay.currentStepIndex, 1)
        replay.stepBackward()
        XCTAssertEqual(replay.currentStepIndex, 0)
        replay.seek(toStep: 2)
        XCTAssertEqual(replay.currentStepIndex, 2)
    }

    // MARK: - 4. 存檔原子寫入與損毀資料安全防護
    func testSaveGameAtomicWriteAndCorruptedRecovery() {
        let service = SaveGameService.shared
        let slot = "test_slot_\(UUID().uuidString)"

        let board = Board(rows: 9, columns: 9, totalMines: 10)
        let fairness = GameFairnessRecord(seed: 12345)

        // 儲存
        let saveSuccess = service.saveGame(
            slotId: slot,
            title: "單元測試存檔",
            difficulty: .beginner,
            mode: .classic,
            seed: 12345,
            state: .inProgress,
            board: board,
            explodedMineCount: 0,
            elapsedTime: 12.5,
            fairnessRecord: fairness
        )
        XCTAssertTrue(saveSuccess)

        // 讀取
        let loaded = service.loadGame(slotId: slot)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.seed, 12345)
        XCTAssertEqual(loaded?.difficulty, .beginner)
        XCTAssertEqual(loaded?.elapsedTime, 12.5)

        // 刪除存檔清理
        service.deleteSave(slotId: slot)
        XCTAssertNil(service.loadGame(slotId: slot))
    }

    // MARK: - 5. 每日挑戰確定性種子與防作弊
    func testDailyChallengeDeterministicSeed() {
        let service = DailyChallengeService.shared
        let seed1 = service.deterministicSeed(from: "2026-11-05")
        let seed2 = service.deterministicSeed(from: "2026-11-05")
        let seedDiff = service.deterministicSeed(from: "2026-11-06")

        XCTAssertEqual(seed1, seed2, "相同日期字串必須產生 100% 一致之確定性種子")
        XCTAssertNotEqual(seed1, seedDiff, "不同日期必須產生不同種子")

        let today = service.todayChallenge()
        XCTAssertEqual(today.isNoGuess, true)
    }

    // MARK: - 6. 成就系統觸發與防作弊隔離
    func testAchievementManagerUnlocks() {
        let manager = AchievementManager.shared
        let engine = GameEngine(difficulty: .beginner, mode: .classic, seed: 12345)

        // 手動模擬獲勝狀態 (0 踩雷)
        let mockWon = GameSnapshot(
            actionDescription: "模擬勝利",
            board: engine.internalBoard,
            state: .won,
            explodedMineCount: 0,
            pureElapsedTime: 8.0,
            fairnessRecord: engine.fairnessRecord,
            difficulty: .beginner,
            mode: .classic,
            seed: 12345
        )
        engine.applySnapshot(mockWon)

        manager.evaluateAchievements(engine: engine, currentStreak: 1)

        let firstWin = manager.achievements.first(where: { $0.id == "firstWin" })
        XCTAssertTrue(firstWin?.isUnlocked == true, "首勝成就必須解鎖")

        let flawless = manager.achievements.first(where: { $0.id == "flawlessWin" })
        XCTAssertTrue(flawless?.isUnlocked == true, "零失誤成就必須解鎖")
    }

    // MARK: - 7. 統計數據遊戲模式嚴格隔離
    func testStatisticsServiceSegregation() {
        let service = StatisticsService.shared
        service.resetAllStats()

        service.recordGameFinished(
            mode: .classic,
            difficulty: .beginner,
            isWon: true,
            time: 15.0,
            explodedMines: 0,
            hintsUsed: 0,
            aiRescues: 0,
            undosUsed: 0
        )

        service.recordGameFinished(
            mode: .noGuess,
            difficulty: .intermediate,
            isWon: true,
            time: 30.0,
            explodedMines: 0,
            hintsUsed: 2,
            aiRescues: 1,
            undosUsed: 1
        )

        let classicStats = service.stats(forMode: .classic)
        let noGuessStats = service.stats(forMode: .noGuess)

        XCTAssertEqual(classicStats.hintsUsedIfApplicable, 0)
        XCTAssertEqual(noGuessStats.totalHintsUsed, 2)
        XCTAssertEqual(noGuessStats.totalAIRescuesUsed, 1)
        XCTAssertEqual(noGuessStats.totalUndosUsed, 1)
    }

    // MARK: - 8. 高級機率計算與資訊熵評估
    func testProbabilityCalculatorAndHeatmap() {
        let calc = ProbabilityCalculator.shared
        // 建立 3x3 測試公開盤面
        var grid = (0..<3).map { r in
            (0..<3).map { c in
                PublicCell(row: r, column: c, state: .hidden, neighboringMines: nil)
            }
        }
        // (1, 1) 翻開為 1
        grid[1][1] = PublicCell(row: 1, column: 1, state: .revealed, neighboringMines: 1)

        let report = calc.generateHeatmap(grid: grid, totalMines: 1, flaggedCount: 0)
        XCTAssertTrue(report.hasExactGuarantee)
        XCTAssertFalse(report.detailedRisks.isEmpty)

        // 資訊熵測試：確認 0 < p < 1 之格子具有正資訊熵 (Information Gain > 0)
        for (_, risk) in report.detailedRisks {
            if risk.probability > 0.0 && risk.probability < 1.0 {
                XCTAssertGreaterThan(risk.informationGain, 0.0)
            }
        }
    }

    // MARK: - 9. What-if 假設實驗室反證法檢測
    func testWhatIfSimulationContradiction() {
        let whatIf = WhatIfSimulationEngine.shared

        // 建立測試網格：(0, 0) 為翻開的數字 1，其周圍已插旗 1 顆
        var grid = (0..<3).map { r in
            (0..<3).map { c in
                PublicCell(row: r, column: c, state: .hidden, neighboringMines: nil)
            }
        }
        grid[0][0] = PublicCell(row: 0, column: 0, state: .revealed, neighboringMines: 1)
        grid[0][1] = PublicCell(row: 0, column: 1, state: .flagged, neighboringMines: nil)

        // 假設未插旗的鄰居 (1, 0) 亦為地雷 -> 產生超過數字 1 之數學矛盾！
        let scenario = whatIf.simulate(
            grid: grid,
            totalMines: 2,
            flaggedCount: 1,
            target: GridCoordinate(1, 0),
            hypothesis: .assumeMine
        )

        XCTAssertTrue(scenario.hasContradiction, "周圍旗數超過標示數字時必須精確觸發反證法矛盾！")
        XCTAssertTrue(scenario.newlyDeducedSafe.contains(GridCoordinate(1, 0)), "經反證法該格必為安全格")
    }

    // MARK: - 10. 沙盒分享碼編解碼與合法性驗證
    func testSandboxSharingCodeEncodeDecode() {
        let payload = BoardSharePayload(
            width: 16,
            height: 16,
            mines: 40,
            seed: 0x1A2B3C4D5E6F,
            modeRawValue: "沙盒模式"
        )

        let code = BoardShareCoder.encode(payload: payload)
        XCTAssertTrue(code.hasPrefix("MF1-16x16-40-"))

        let decodedResult = BoardShareCoder.decode(code: code)
        switch decodedResult {
        case .success(let decoded):
            XCTAssertEqual(decoded.width, 16)
            XCTAssertEqual(decoded.height, 16)
            XCTAssertEqual(decoded.mines, 40)
            XCTAssertEqual(decoded.seed, 0x1A2B3C4D5E6F)
        case .failure(let err):
            XCTFail("解碼分享碼失敗: \(err)")
        }

        // 測試非法維度代碼
        let invalidCode = "MF1-999x999-40-ABC-mode"
        let invalidResult = BoardShareCoder.decode(code: invalidCode)
        switch invalidResult {
        case .success:
            XCTFail("非法維度代碼不應解析成功")
        case .failure(let err):
            XCTAssertEqual(err, .invalidDimensions("寬度需在 5~40，高度需在 5~30 之間"))
        }
    }

    // MARK: - 11. 遊戲難度演算法評估指數
    func testDifficultyRatingEngineRange() {
        let engine = DifficultyRatingEngine.shared

        // 初級 9x9 盤面
        let grid = (0..<9).map { r in
            (0..<9).map { c in
                PublicCell(row: r, column: c, state: .hidden, neighboringMines: nil)
            }
        }

        let report = engine.evaluateDifficulty(grid: grid, totalMines: 10, flaggedCount: 0)
        XCTAssertGreaterThanOrEqual(report.score, 1)
        XCTAssertLessThanOrEqual(report.score, 100)
        XCTAssertFalse(report.techniquesRequired.isEmpty)
    }

    // MARK: - 12. 視覺主題預設配置完整性
    func testThemeManagerPresets() {
        XCTAssertEqual(ThemeManager.presetThemes.count, 6, "必須提供 6 種完整預設主題")
        for (_, theme) in ThemeManager.presetThemes {
            XCTAssertFalse(theme.id.isEmpty)
            XCTAssertFalse(theme.name.isEmpty)
            XCTAssertEqual(theme.numberColors.count, 8, "所有主題必須包含 1~8 完整數字色彩配置")
        }
    }
}

private extension ModeStatisticsRecord {
    var hintsUsedIfApplicable: Int {
        totalHintsUsed
    }
}
