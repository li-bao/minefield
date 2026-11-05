import XCTest
@testable import Minefield

final class MinefieldTests: XCTestCase {

    // MARK: - 1. 難度配置測試

    func testGameDifficultyConfigurations() {
        let beginner = GameDifficulty.beginner.configuration
        XCTAssertEqual(beginner.rows, 9)
        XCTAssertEqual(beginner.columns, 9)
        XCTAssertEqual(beginner.mines, 10)

        let intermediate = GameDifficulty.intermediate.configuration
        XCTAssertEqual(intermediate.rows, 16)
        XCTAssertEqual(intermediate.columns, 16)
        XCTAssertEqual(intermediate.mines, 40)

        let expert = GameDifficulty.expert.configuration
        XCTAssertEqual(expert.rows, 16)
        XCTAssertEqual(expert.columns, 30)
        XCTAssertEqual(expert.mines, 99)

        let customConfig = CustomBoardConfig(width: 25, height: 20, mines: 80)
        let custom = GameDifficulty.custom(customConfig).configuration
        XCTAssertEqual(custom.rows, 20)
        XCTAssertEqual(custom.columns, 25)
        XCTAssertEqual(custom.mines, 80)
    }

    // MARK: - 2. 自訂棋盤驗證測試

    func testCustomBoardValidationRules() {
        // 合法測試
        let valid = CustomBoardConfig.validate(width: 20, height: 15, mines: 50)
        XCTAssertTrue(caseSuccess(valid))

        // 寬度過小與過大
        let tooNarrow = CustomBoardConfig.validate(width: 4, height: 10, mines: 10)
        XCTAssertEqual(tooNarrow, .failure(.widthOutOfRange(current: 4, min: 5, max: 40)))

        let tooWide = CustomBoardConfig.validate(width: 41, height: 10, mines: 10)
        XCTAssertEqual(tooWide, .failure(.widthOutOfRange(current: 41, min: 5, max: 40)))

        // 高度過小與過大
        let tooShort = CustomBoardConfig.validate(width: 10, height: 4, mines: 10)
        XCTAssertEqual(tooShort, .failure(.heightOutOfRange(current: 4, min: 5, max: 30)))

        let tooTall = CustomBoardConfig.validate(width: 10, height: 31, mines: 10)
        XCTAssertEqual(tooTall, .failure(.heightOutOfRange(current: 31, min: 5, max: 30)))

        // 地雷數過少與過多 (5x5 盤面，最多 25 - 9 = 16 顆)
        let tooFewMines = CustomBoardConfig.validate(width: 5, height: 5, mines: 0)
        XCTAssertEqual(tooFewMines, .failure(.minesOutOfRange(current: 0, min: 1, max: 16)))

        let tooManyMines = CustomBoardConfig.validate(width: 5, height: 5, mines: 17)
        XCTAssertEqual(tooManyMines, .failure(.minesOutOfRange(current: 17, min: 1, max: 16)))
    }

    private func caseSuccess<T, E>(_ result: Result<T, E>) -> Bool {
        if case .success = result { return true }
        return false
    }

    // MARK: - 3. 地雷總數與分佈測試

    func testTotalMineCountAcrossDifficulties() {
        let difficulties: [GameDifficulty] = [
            .beginner,
            .intermediate,
            .expert,
            .custom(CustomBoardConfig(width: 12, height: 10, mines: 25))
        ]

        for diff in difficulties {
            let engine = GameEngine(difficulty: diff, seed: 12345)
            XCTAssertEqual(engine.state, .ready)

            // 首發點擊以佈局地雷
            engine.revealCell(atRow: 0, column: 0)

            // 統計 internalBoard 實際的地雷數量
            var actualMines = 0
            for r in 0..<engine.internalBoard.rows {
                for c in 0..<engine.internalBoard.columns {
                    if engine.internalBoard[r, c].hasMine {
                        actualMines += 1
                    }
                }
            }
            XCTAssertEqual(actualMines, diff.configuration.mines, "難度 \(diff.title) 地雷總數不符")
        }
    }

    // MARK: - 4. 首步點擊 3×3 安全區機制測試

    func testFirstClick3x3SafeZone() {
        let seeds: [UInt64] = [1, 42, 999, 88888, 987654321]

        for seed in seeds {
            let engine = GameEngine(difficulty: .intermediate, seed: seed)
            let clickR = 8
            let clickC = 8

            engine.revealCell(atRow: clickR, column: clickC)
            XCTAssertEqual(engine.state, .inProgress)

            // 驗證首擊點與周圍 8 格絕無地雷
            for dr in -1...1 {
                for dc in -1...1 {
                    let r = clickR + dr
                    let c = clickC + dc
                    if engine.internalBoard.isValidCoordinate(row: r, column: c) {
                        XCTAssertFalse(
                            engine.internalBoard[r, c].hasMine,
                            "Seed \(seed) 下安全區座標 (\(r), \(c)) 不應存在地雷"
                        )
                    }
                }
            }
        }
    }

    func testCornerFirstClickSafeZone() {
        let engine = GameEngine(difficulty: .beginner, seed: 777)
        // 點擊左上角落 (0, 0)
        engine.revealCell(atRow: 0, column: 0)

        for dr in 0...1 {
            for dc in 0...1 {
                XCTAssertFalse(
                    engine.internalBoard[dr, dc].hasMine,
                    "角落安全區 (\(dr), \(dc)) 不應有雷"
                )
            }
        }
    }

    // MARK: - 5. 相鄰地雷計算準確度測試

    func testNeighboringMinesCalculationAccuracy() {
        let engine = GameEngine(difficulty: .intermediate, seed: 2026)
        engine.revealCell(atRow: 5, column: 5)

        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                let cell = engine.internalBoard[r, c]
                if !cell.hasMine {
                    let expectedMines = engine.internalBoard.neighborCoordinates(ofRow: r, column: c).filter {
                        engine.internalBoard[$0.row, $0.column].hasMine
                    }.count
                    XCTAssertEqual(cell.neighboringMines, expectedMines, "格位 (\(r),\(c)) 的鄰近雷數計算錯誤")
                }
            }
        }
    }

    // MARK: - 6. 插旗與防誤翻測試

    func testFlaggingAndProtection() {
        let engine = GameEngine(difficulty: .beginner, seed: 100)
        XCTAssertEqual(engine.remainingMinesToFlag, 10)

        // 第一次插旗
        let flagSuccess = engine.toggleFlag(atRow: 2, column: 3)
        XCTAssertTrue(flagSuccess)
        XCTAssertTrue(engine.internalBoard[2, 3].isFlagged)
        XCTAssertEqual(engine.remainingMinesToFlag, 9)

        // 嘗試翻開已插旗格子：必須被禁止！
        let revealBlocked = engine.revealCell(atRow: 2, column: 3)
        XCTAssertFalse(revealBlocked)
        XCTAssertTrue(engine.internalBoard[2, 3].isFlagged)

        // 取消插旗
        let unflagSuccess = engine.toggleFlag(atRow: 2, column: 3)
        XCTAssertTrue(unflagSuccess)
        XCTAssertFalse(engine.internalBoard[2, 3].isFlagged)
        XCTAssertEqual(engine.remainingMinesToFlag, 10)
    }

    // MARK: - 7. 廣度優先 Flood Fill 自動展開與防護旗幟測試

    func testFloodFillDoesNotRevealFlaggedCells() {
        let engine = GameEngine(difficulty: .beginner, seed: 2024)

        // 首擊 (4, 4) 觸發安全區
        engine.revealCell(atRow: 4, column: 4)

        // 尋找一個未翻開且確定無地雷的鄰近格子並插旗
        var flaggedCoord: (row: Int, column: Int)?
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                let cell = engine.internalBoard[r, c]
                if cell.state == .hidden && !cell.hasMine {
                    engine.toggleFlag(atRow: r, column: c)
                    flaggedCoord = (r, c)
                    break
                }
            }
            if flaggedCoord != nil { break }
        }

        XCTAssertNotNil(flaggedCoord)
        let (fr, fc) = flaggedCoord!
        XCTAssertTrue(engine.internalBoard[fr, fc].isFlagged)

        // 觸發連鎖翻開相鄰格子
        for (nr, nc) in engine.internalBoard.neighborCoordinates(ofRow: fr, column: fc) {
            if engine.internalBoard[nr, nc].state == .hidden {
                engine.revealCell(atRow: nr, column: nc)
            }
        }

        // 驗證已插旗的格子依然處於 flagged，沒有被 Flood Fill 破壞或翻開
        XCTAssertTrue(engine.internalBoard[fr, fc].isFlagged)
        XCTAssertFalse(engine.internalBoard[fr, fc].isRevealed)
    }

    // MARK: - 8. 快捷翻開 (Chording) 測試

    func testChordingOperation() {
        let engine = GameEngine(difficulty: .beginner, seed: 333)
        engine.revealCell(atRow: 4, column: 4)

        // 尋找一個已翻開且數字大於 0 的格子
        var targetCoord: (row: Int, column: Int)?
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                let cell = engine.internalBoard[r, c]
                if cell.state == .revealed && cell.neighboringMines > 0 {
                    targetCoord = (r, c)
                    break
                }
            }
            if targetCoord != nil { break }
        }

        guard let (tr, tc) = targetCoord else {
            XCTFail("找不到合適的數字格進行測試")
            return
        }

        let _ = engine.internalBoard[tr, tc].neighboringMines
        let neighbors = engine.internalBoard.neighborCoordinates(ofRow: tr, column: tc)
        let mineNeighbors = neighbors.filter { engine.internalBoard[$0.row, $0.column].hasMine }

        // 若旗幟數不足，執行 Chording 應回傳 false 不進行翻開
        let chordIncomplete = engine.chordReveal(atRow: tr, column: tc)
        XCTAssertFalse(chordIncomplete)

        // 正確為鄰近地雷插旗
        for m in mineNeighbors {
            if !engine.internalBoard[m.row, m.column].isFlagged {
                engine.toggleFlag(atRow: m.row, column: m.column)
            }
        }

        // 現在插旗數 == 數字，執行 Chording
        let chordSuccess = engine.chordReveal(atRow: tr, column: tc)
        XCTAssertTrue(chordSuccess)

        // 驗證所有非地雷相鄰格子已被翻開
        for n in neighbors {
            if !engine.internalBoard[n.row, n.column].hasMine {
                XCTAssertEqual(engine.internalBoard[n.row, n.column].state, .revealed)
            }
        }
    }

    // MARK: - 9. 經典模式 (Classic Mode) 踩雷即負測試

    func testClassicModeDefeat() {
        let engine = GameEngine(difficulty: .beginner, mode: .classic, seed: 555)
        engine.revealCell(atRow: 0, column: 0) // 開局

        // 尋找一顆地雷並點擊
        var mineCoord: (row: Int, column: Int)?
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if engine.internalBoard[r, c].hasMine {
                    mineCoord = (r, c)
                    break
                }
            }
            if mineCoord != nil { break }
        }

        guard let (mr, mc) = mineCoord else {
            XCTFail("找不到地雷座標")
            return
        }

        let hitMine = engine.revealCell(atRow: mr, column: mc)
        XCTAssertTrue(hitMine)
        XCTAssertEqual(engine.state, .lost)
        XCTAssertEqual(engine.internalBoard[mr, mc].state, .exploded)

        // 經典模式失敗後，所有其他地雷應被翻開
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if engine.internalBoard[r, c].hasMine && !(r == mr && c == mc) {
                    XCTAssertTrue(engine.internalBoard[r, c].isRevealed)
                }
            }
        }

        // 失敗後無法再操作
        XCTAssertFalse(engine.revealCell(atRow: 0, column: 1))
        XCTAssertFalse(engine.toggleFlag(atRow: 0, column: 1))
    }

    // MARK: - 10. 懲罰模式 (Penalty Mode) 累計秒數與可繼續遊戲測試

    func testPenaltyModeOperation() {
        let engine = GameEngine(difficulty: .beginner, mode: .penalty, penaltySecondsPerMine: 30.0, seed: 888)
        engine.revealCell(atRow: 0, column: 0) // 開局

        // 尋找一顆地雷踩擊
        var mineCoord: (row: Int, column: Int)?
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if engine.internalBoard[r, c].hasMine {
                    mineCoord = (r, c)
                    break
                }
            }
            if mineCoord != nil { break }
        }

        guard let (mr, mc) = mineCoord else {
            XCTFail("找不到地雷")
            return
        }

        engine.revealCell(atRow: mr, column: mc)

        // 懲罰模式下：遊戲依然進行中，狀態非 lost
        XCTAssertEqual(engine.state, .inProgress)
        XCTAssertEqual(engine.internalBoard[mr, mc].state, .exploded)
        XCTAssertEqual(engine.explodedMineCount, 1)

        // 模擬耗時 10 秒
        engine.simulatedElapsedTime = 10.0
        XCTAssertEqual(engine.pureElapsedTime, 10.0)
        // 總耗時應為 10s + (1 * 30s) = 40s
        XCTAssertEqual(engine.totalTimeWithPenalties, 40.0)

        // 自訂懲罰時間為 45 秒測試
        engine.penaltySecondsPerMine = 45.0
        XCTAssertEqual(engine.totalTimeWithPenalties, 55.0)
    }

    // MARK: - 11. 勝利判定與不要求插滿地雷測試

    func testVictoryConditionWithoutFullFlagging() {
        let engine = GameEngine(difficulty: .beginner, seed: 999)
        engine.revealCell(atRow: 4, column: 4)

        // 依序翻開所有非地雷格子
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if !engine.internalBoard[r, c].hasMine && engine.internalBoard[r, c].state == .hidden {
                    engine.revealCell(atRow: r, column: c)
                }
            }
        }

        // 即使玩家一顆旗幟都沒插，只要所有安全格翻開即獲勝！
        XCTAssertEqual(engine.state, .won)

        // 勝利後自動將未爆地雷插旗
        for r in 0..<engine.internalBoard.rows {
            for c in 0..<engine.internalBoard.columns {
                if engine.internalBoard[r, c].hasMine {
                    XCTAssertTrue(engine.internalBoard[r, c].isFlagged)
                }
            }
        }
    }

    // MARK: - 12. Seed 重現性與重設測試

    func testSeedReproducibilityAndRestart() {
        let seed: UInt64 = 778899
        let engine1 = GameEngine(difficulty: .intermediate, seed: seed)
        engine1.revealCell(atRow: 5, column: 5)

        let engine2 = GameEngine(difficulty: .intermediate, seed: seed)
        engine2.revealCell(atRow: 5, column: 5)

        // 驗證兩個由相同 Seed 與相同首步產生的盤面完全一致
        for r in 0..<16 {
            for c in 0..<16 {
                XCTAssertEqual(
                    engine1.internalBoard[r, c].hasMine,
                    engine2.internalBoard[r, c].hasMine
                )
                XCTAssertEqual(
                    engine1.internalBoard[r, c].neighboringMines,
                    engine2.internalBoard[r, c].neighboringMines
                )
            }
        }

        // 測試 restartCurrentGame 保留相同 seed
        engine1.restartCurrentGame()
        XCTAssertEqual(engine1.state, .ready)
        XCTAssertEqual(engine1.explodedMineCount, 0)
        engine1.revealCell(atRow: 5, column: 5)

        for r in 0..<16 {
            for c in 0..<16 {
                XCTAssertEqual(
                    engine1.internalBoard[r, c].hasMine,
                    engine2.internalBoard[r, c].hasMine
                )
            }
        }
    }

    // MARK: - 13. 公開視圖資訊隱藏 (避免 AI/Solver 作弊) 測試

    func testPublicBoardInformationHiding() {
        let engine = GameEngine(difficulty: .beginner, seed: 123)
        engine.revealCell(atRow: 0, column: 0)

        let publicGrid = engine.publicBoard()
        XCTAssertEqual(publicGrid.count, 9)
        XCTAssertEqual(publicGrid[0].count, 9)

        for row in publicGrid {
            for pCell in row {
                if pCell.isHidden || pCell.isFlagged {
                    // 未翻開或插旗的格子，絕不可暴露數字
                    XCTAssertNil(pCell.neighboringMines)
                } else if pCell.state == .revealed {
                    XCTAssertNotNil(pCell.neighboringMines)
                }
            }
        }
    }
}
