import SwiftUI

/// 完整遊戲進行畫面 (Phase 4.75 終極功能版)
public struct GameView: View {
    @ObservedObject public var engine: GameEngine
    public let longPressDuration: TimeInterval
    public let onOpenSettings: () -> Void
    public let onBackToMenu: () -> Void
    public let onOpenOllamaSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var settings = AppSettingsManager.shared
    @StateObject private var reasoningManager = ReasoningHistoryManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    // MARK: - 智慧排雷與提示狀態
    @State private var isSolverActive = false
    @State private var solverResult: SolverResult?
    @State private var targetedHintCoord: (Int, Int)?
    @State private var showingHintSheet = false
    @State private var activeHintRecommendation: CellRecommendation?

    // MARK: - AI 專家與問答狀態
    @State private var showingAISheet = false
    @State private var isAILoading = false
    @State private var aiAnalysis: ValidatedAIAnalysis?
    @State private var aiErrorMessage: String?
    @State private var aiTask: Task<Void, Never>?
    @State private var showingAIChatSheet = false

    // MARK: - 實驗室與擴充功能彈窗
    @State private var showingRepairSheet = false
    @State private var activeRepairResult: BoardRepairResult?
    @State private var showingReasoningHistory = false
    @State private var showingCoachSheet = false
    @State private var showingHeatmapSheet = false
    @State private var showingWhatIfSheet = false
    @State private var showingAutoPlaySheet = false
    @State private var showingReplaySheet = false
    @State private var repairBannerText: String?

    public init(
        engine: GameEngine,
        longPressDuration: TimeInterval = 0.45,
        onOpenSettings: @escaping () -> Void,
        onBackToMenu: @escaping () -> Void,
        onOpenOllamaSettings: @escaping () -> Void
    ) {
        self.engine = engine
        self.longPressDuration = longPressDuration
        self.onOpenSettings = onOpenSettings
        self.onBackToMenu = onBackToMenu
        self.onOpenOllamaSettings = onOpenOllamaSettings
    }

    public var body: some View {
        ZStack {
            ColorTheme.windowBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. 頂部狀態列
                GameHeaderView(
                    engine: engine,
                    onOpenSettings: onOpenSettings,
                    onBackToMenu: onBackToMenu
                )

                // 動態防猜修復提示條
                if let banner = repairBannerText {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(ColorTheme.mintAccent)
                        Text(banner)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button(action: { repairBannerText = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTheme.mintAccent.opacity(0.15))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 2. 中央自適應棋盤區域 (含排雷機率與高亮光環)
                BoardGridView(
                    engine: engine,
                    longPressDuration: longPressDuration,
                    highlights: currentBoardHighlights
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 3. 底部功能控制面板 (全功能控制列)
                SideControlPanelView(
                    engine: engine,
                    isSolverActive: isSolverActive,
                    canRepair: solverResult?.status == .guessRequired,
                    onToggleSmartSolver: toggleSmartSolver,
                    onHintRequested: handleHintRequest,
                    onAutoSolveRequested: { showingAutoPlaySheet = true },
                    onAIExpertRequested: triggerAIExpertAnalysis,
                    onReasoningHistoryRequested: { showingReasoningHistory = true },
                    onRepairRequested: openRepairPreview,
                    onUndo: {
                        _ = engine.performUndo()
                        if isSolverActive { runSolverAnalysis() }
                    },
                    onRedo: {
                        _ = engine.performRedo()
                        if isSolverActive { runSolverAnalysis() }
                    },
                    onOpenHeatmap: { showingHeatmapSheet = true },
                    onOpenCoach: { showingCoachSheet = true },
                    onOpenWhatIf: { showingWhatIfSheet = true },
                    onOpenAIChat: { showingAIChatSheet = true },
                    onOpenReplay: { showingReplaySheet = true }
                )
            }

            // 勝利浮層結算卡
            if engine.state == .won {
                victoryOverlay
            }

            // 經典模式失敗浮層卡
            if engine.state == .lost {
                defeatOverlay
            }

            // 隱形無障礙鍵盤快捷鍵按鈕
            keyboardShortcutTriggers
        }
        .sheet(isPresented: $showingHintSheet) {
            if let rec = activeHintRecommendation, let res = solverResult {
                HintSheet(
                    recommendation: rec,
                    status: res.status,
                    onHighlightOnly: {
                        targetedHintCoord = (rec.row, rec.column)
                        isSolverActive = true
                    },
                    onApply: {
                        applyRecommendation(rec)
                    }
                )
            }
        }
        .sheet(isPresented: $showingAISheet) {
            AIAnalysisSheet(
                analysis: aiAnalysis,
                isLoading: isAILoading,
                errorMessage: aiErrorMessage,
                onApplySuggestion: { sug in
                    applyAISuggestion(sug)
                },
                onRetry: {
                    triggerAIExpertAnalysis()
                },
                onOpenOllamaSettings: onOpenOllamaSettings
            )
        }
        .sheet(isPresented: $showingRepairSheet) {
            if let result = activeRepairResult {
                BoardRepairSheet(
                    currentBoard: engine.internalBoard,
                    repairResult: result,
                    onApply: {
                        if let repaired = result.repairedBoard {
                            engine.applyRepairedBoard(repaired, movedMines: result.movedMinesCount)
                            runSolverAnalysis()
                            repairBannerText = "已成功套用棋盤修復 (微調 \(result.movedMinesCount) 顆地雷)，已產生必然安全格！"
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingReasoningHistory) {
            ReasoningHistorySheet(historyManager: reasoningManager)
        }
        .sheet(isPresented: $showingCoachSheet) {
            AICoachSheet(engine: engine) {
                showingCoachSheet = false
            }
        }
        .sheet(isPresented: $showingHeatmapSheet) {
            RiskHeatmapSheet(engine: engine) {
                showingHeatmapSheet = false
            }
        }
        .sheet(isPresented: $showingWhatIfSheet) {
            WhatIfSheet(engine: engine) {
                showingWhatIfSheet = false
            }
        }
        .sheet(isPresented: $showingAutoPlaySheet) {
            AutoPlayControlSheet(engine: engine) {
                showingAutoPlaySheet = false
            }
        }
        .sheet(isPresented: $showingAIChatSheet) {
            AIChatPanelSheet(engine: engine) {
                showingAIChatSheet = false
            }
        }
        .sheet(isPresented: $showingReplaySheet) {
            ReplayViewerSheet {
                showingReplaySheet = false
            }
        }
        .onChange(of: engine.internalBoard) {
            if isSolverActive {
                runSolverAnalysis()
            }
            triggerAutoSave()
        }
        .onChange(of: engine.state) {
            handleGameStateChange()
        }
        .onAppear {
            // 綁定動態防猜回呼
            engine.onBoardRepaired = { rep in
                withAnimation {
                    self.repairBannerText = "防猜機制生效：已微調 \(rep.movedMinesCount) 顆隱藏雷，產生 \(rep.newSafeCells.count) 個必然安全步！"
                }
                if isSolverActive {
                    runSolverAnalysis()
                }
            }
        }
    }

    // MARK: - 計算棋盤即時高亮字典
    private var currentBoardHighlights: [String: CellHighlight] {
        var map = [String: CellHighlight]()

        if let (tr, tc) = targetedHintCoord {
            map["\(tr),\(tc)"] = .target
        }

        if isSolverActive, let res = solverResult {
            for (key, probInfo) in res.probabilities {
                if key == "\(targetedHintCoord?.0 ?? -1),\(targetedHintCoord?.1 ?? -1)" {
                    continue
                }
                if probInfo.isCertainSafe {
                    map[key] = .safe
                } else if probInfo.isCertainMine {
                    map[key] = .mine
                } else if probInfo.mineProbability > 0.0 && probInfo.mineProbability < 1.0 {
                    map[key] = .guess(risk: probInfo.mineProbability)
                }
            }
        }

        return map
    }

    // MARK: - 智慧排雷與提示觸發
    private func toggleSmartSolver() {
        isSolverActive.toggle()
        if isSolverActive {
            runSolverAnalysis()
        } else {
            targetedHintCoord = nil
        }
    }

    private func runSolverAnalysis() {
        let grid = engine.publicBoard()
        let result = SmartSolver.shared.analyze(
            grid: grid,
            totalMines: engine.internalBoard.totalMines,
            flaggedCount: engine.internalBoard.flaggedCount
        )
        self.solverResult = result

        // 記錄至推理歷程
        if let rec = result.recommendedMove {
            reasoningManager.addStep(
                ReasoningStep(
                    method: result.status == .safe || result.status == .mine ? "CSP 數學約束推導" : "機率風險分析",
                    resultType: result.status.rawValue,
                    targetCell: GridCoordinate(rec.row, rec.column),
                    riskPercentage: rec.mineProbability,
                    wasRepaired: false,
                    detail: rec.reason
                )
            )
        }
    }

    private func handleHintRequest() {
        runSolverAnalysis()
        guard let res = solverResult, let rec = res.recommendedMove else {
            return
        }
        self.activeHintRecommendation = rec
        self.showingHintSheet = true
    }

    private func applyRecommendation(_ rec: CellRecommendation) {
        targetedHintCoord = nil
        if rec.action == .reveal || rec.action == .guess {
            engine.revealCell(atRow: rec.row, column: rec.column)
        } else if rec.action == .flag {
            if !engine.internalBoard[rec.row, rec.column].isFlagged {
                engine.toggleFlag(atRow: rec.row, column: rec.column)
            }
        }
        if isSolverActive {
            runSolverAnalysis()
        }
    }

    // MARK: - 手動開啟棋盤修復預覽
    private func openRepairPreview() {
        runSolverAnalysis()
        guard let res = solverResult else { return }

        let result = BoardRepairEngine.shared.attemptRepair(
            board: engine.internalBoard,
            solverResult: res
        )
        self.activeRepairResult = result
        self.showingRepairSheet = true
    }

    // MARK: - AI 專家分析觸發 (非同步，不凍結 UI)
    private func triggerAIExpertAnalysis() {
        aiTask?.cancel()
        isAILoading = true
        aiErrorMessage = nil
        showingAISheet = true

        let grid = engine.publicBoard()
        let total = engine.internalBoard.totalMines
        let flags = engine.internalBoard.flaggedCount
        let host = settings.ollamaHost
        let model = settings.ollamaModel

        aiTask = Task {
            do {
                let analysis = try await AIEngine.shared.analyzeBoardWithAI(
                    grid: grid,
                    totalMines: total,
                    flaggedCount: flags,
                    host: host,
                    model: model,
                    timeout: 25.0
                )
                await MainActor.run {
                    self.aiAnalysis = analysis
                    self.isAILoading = false

                    self.reasoningManager.addStep(
                        ReasoningStep(
                            method: "AI 專家局勢分析 (\(model))",
                            resultType: analysis.solverStatus.rawValue,
                            wasRepaired: false,
                            detail: analysis.summary
                        )
                    )
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isAILoading = false
                }
            }
        }
    }

    private func applyAISuggestion(_ sug: ValidatedAISuggestion) {
        if sug.action == .reveal || sug.action == .guess {
            engine.revealCell(atRow: sug.row, column: sug.column)
        } else if sug.action == .flag {
            if !engine.internalBoard[sug.row, sug.column].isFlagged {
                engine.toggleFlag(atRow: sug.row, column: sug.column)
            }
        }
        if isSolverActive {
            runSolverAnalysis()
        }
    }

    // MARK: - 自動存檔與遊戲結算處理
    private func triggerAutoSave() {
        if engine.state == .inProgress {
            _ = SaveGameService.shared.autoSave(
                difficulty: engine.difficulty,
                mode: engine.mode,
                seed: engine.currentSeed,
                state: engine.state,
                board: engine.internalBoard,
                explodedMineCount: engine.explodedMineCount,
                elapsedTime: engine.pureElapsedTime,
                fairnessRecord: engine.fairnessRecord,
                undoStack: UndoRedoManager.shared.undoStack,
                redoStack: UndoRedoManager.shared.redoStack
            )
        } else if engine.state == .won || engine.state == .lost {
            SaveGameService.shared.clearAutoSave()
        }
    }

    private func handleGameStateChange() {
        if engine.state == .won {
            AudioManager.shared.play(.victory)
            AchievementManager.shared.evaluateAchievements(engine: engine)
            StatisticsService.shared.recordGameFinished(
                mode: engine.mode,
                difficulty: engine.difficulty,
                isWon: true,
                time: engine.totalTimeWithPenalties,
                explodedMines: engine.explodedMineCount,
                hintsUsed: engine.fairnessRecord.hintCount,
                aiRescues: engine.fairnessRecord.aiRescueCount,
                undosUsed: engine.fairnessRecord.undoCount
            )
            triggerAutoSave()
        } else if engine.state == .lost {
            AudioManager.shared.play(.defeat)
            StatisticsService.shared.recordGameFinished(
                mode: engine.mode,
                difficulty: engine.difficulty,
                isWon: false,
                time: engine.totalTimeWithPenalties,
                explodedMines: engine.explodedMineCount,
                hintsUsed: engine.fairnessRecord.hintCount,
                aiRescues: engine.fairnessRecord.aiRescueCount,
                undosUsed: engine.fairnessRecord.undoCount
            )
            triggerAutoSave()
        }
    }

    // MARK: - 無障礙鍵盤快捷鍵輔助按鈕
    private var keyboardShortcutTriggers: some View {
        Group {
            Button("") { _ = engine.performUndo() }
                .keyboardShortcut("u", modifiers: [])
            Button("") { _ = engine.performRedo() }
                .keyboardShortcut("u", modifiers: [.shift])
            Button("") { handleHintRequest() }
                .keyboardShortcut("h", modifiers: [])
            Button("") { toggleSmartSolver() }
                .keyboardShortcut("s", modifiers: [])
            Button("") { showingAIChatSheet = true }
                .keyboardShortcut("a", modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    // MARK: - 勝利浮層
    @ViewBuilder
    private var victoryOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(ColorTheme.amberWarning)
                    .shadow(color: ColorTheme.amberWarning.opacity(0.5), radius: 10, x: 0, y: 4)

                VStack(spacing: 6) {
                    Text("掃雷勝利！")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text(engine.fairnessRecord.isPureClassicValid ? "⭐ 純經典純手工通關認證" : "動態智慧輔助通關")
                        .font(.system(size: 14))
                        .foregroundStyle(engine.fairnessRecord.isPureClassicValid ? ColorTheme.amberWarning : .secondary)
                }

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("總計耗時")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f 秒", engine.totalTimeWithPenalties))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(ColorTheme.mintAccent)
                    }

                    if engine.fairnessRecord.repairCount > 0 {
                        Divider().frame(height: 30)
                        VStack(spacing: 4) {
                            Text("防猜修復")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("\(engine.fairnessRecord.repairCount) 次 (移 \(engine.fairnessRecord.movedMinesCount) 雷)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ColorTheme.indigoAccent)
                        }
                    }

                    if engine.explodedMineCount > 0 {
                        Divider().frame(height: 30)
                        VStack(spacing: 4) {
                            Text("踩雷懲罰")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("\(engine.explodedMineCount) 次 (+\(Int(Double(engine.explodedMineCount) * engine.penaltySecondsPerMine))s)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ColorTheme.crimsonExplosion)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(ColorTheme.cardBackground(for: colorScheme)))

                HStack(spacing: 14) {
                    Button("回主選單") {
                        onBackToMenu()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.1)))

                    Button("再來一局") {
                        engine.restartCurrentGame()
                        isSolverActive = false
                        repairBannerText = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ColorTheme.mintAccent))
                    .foregroundStyle(.black)
                    .fontWeight(.bold)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(ColorTheme.elevatedCardBackground(for: colorScheme)).shadow(radius: 20))
            .frame(maxWidth: 420)
        }
    }

    // MARK: - 失敗浮層
    @ViewBuilder
    private var defeatOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "burst.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(ColorTheme.crimsonExplosion)
                    .shadow(color: ColorTheme.crimsonExplosion.opacity(0.5), radius: 10, x: 0, y: 4)

                VStack(spacing: 6) {
                    Text("踩中地雷！")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                    Text("經典模式下一擊斃命，再接再厲！")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    Button("回主選單") {
                        onBackToMenu()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.1)))

                    Button("重新挑戰") {
                        engine.restartCurrentGame()
                        isSolverActive = false
                        repairBannerText = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ColorTheme.crimsonExplosion))
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(ColorTheme.elevatedCardBackground(for: colorScheme)).shadow(radius: 20))
            .frame(maxWidth: 360)
        }
    }
}
