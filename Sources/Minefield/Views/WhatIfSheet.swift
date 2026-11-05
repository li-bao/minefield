import SwiftUI

/// What-if 假設推論模擬實驗室面板 (What-if Analysis Sheet)
public struct WhatIfSheet: View {
    public let engine: GameEngine
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedRow: Int = 0
    @State private var selectedCol: Int = 0
    @State private var hypothesis: HypothesisType = .assumeMine
    @State private var scenario: SimulationScenario?

    public init(engine: GameEngine, onDismiss: @escaping () -> Void) {
        self.engine = engine
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("What-if 假設棋局實驗室")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Text("在獨立模擬環境中測試：「如果此格為雷或安全格，接下來會發生什麼？」\n此操作完全隔離，絕對不影響真正遊戲進度。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()

            // 參數設定
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Text("座標列 (R):")
                        .font(.system(size: 13, weight: .medium))
                    Stepper("\(selectedRow)", value: $selectedRow, in: 0...max(0, engine.internalBoard.rows - 1))
                }

                HStack(spacing: 8) {
                    Text("座標行 (C):")
                        .font(.system(size: 13, weight: .medium))
                    Stepper("\(selectedCol)", value: $selectedCol, in: 0...max(0, engine.internalBoard.columns - 1))
                }

                Picker("假設條件", selection: $hypothesis) {
                    ForEach(HypothesisType.allCases, id: \.self) { hyp in
                        Text(hyp.rawValue).tag(hyp)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(ColorTheme.cardBackground(for: colorScheme))

            Divider()

            // 模擬結果輸出
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let sc = scenario {
                        // 狀態卡片
                        HStack {
                            Image(systemName: sc.hasContradiction ? "exclamationmark.shield.fill" : "arrow.triangle.branch")
                                .foregroundStyle(sc.hasContradiction ? Color.red : ColorTheme.mintAccent)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sc.hasContradiction ? "檢測到反證法邏輯矛盾！" : "假設成立之連鎖推導")
                                    .font(.system(size: 15, weight: .bold))
                                Text(sc.pedagogicalSummary)
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(sc.hasContradiction ? Color.red.opacity(0.12) : ColorTheme.mintAccent.opacity(0.12))
                        .cornerRadius(10)

                        if let reason = sc.contradictionReason {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("⚠️ 矛盾產生原因")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(reason)
                                    .font(.system(size: 12))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(8)
                        }

                        // 新解鎖成果
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("連鎖解鎖安全格")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(sc.newlyDeducedSafe.count) 個")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(ColorTheme.mintAccent)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("連鎖確定地雷格")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(sc.newlyDeducedMines.count) 顆")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(8)
                        }

                    } else {
                        Text("請選擇一個未翻開座標並點擊下方「執行假設模擬」。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("執行假設模擬") {
                    runSimulation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Spacer()

                Button("完成") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .frame(width: 540, height: 540)
        .background(ColorTheme.windowBackground(for: colorScheme))
        .onAppear {
            findFirstHiddenCoordinate()
            runSimulation()
        }
    }

    private func findFirstHiddenCoordinate() {
        let grid = engine.publicBoard()
        for r in 0..<grid.count {
            for c in 0..<(grid.first?.count ?? 0) {
                if grid[r][c].isHidden {
                    selectedRow = r
                    selectedCol = c
                    return
                }
            }
        }
    }

    private func runSimulation() {
        let sc = WhatIfSimulationEngine.shared.simulate(
            grid: engine.publicBoard(),
            totalMines: engine.internalBoard.totalMines,
            flaggedCount: engine.internalBoard.flaggedCount,
            target: GridCoordinate(selectedRow, selectedCol),
            hypothesis: hypothesis
        )
        self.scenario = sc
    }
}
