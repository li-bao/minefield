import SwiftUI

/// AI 解題教練面板視圖 (AI Puzzle Coach Sheet)
public struct AICoachSheet: View {
    public let engine: GameEngine
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedLevel: CoachLevel = .intermediate
    @State private var lesson: CoachLesson?

    public init(engine: GameEngine, onDismiss: @escaping () -> Void) {
        self.engine = engine
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("AI 智慧解題教練")
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

            // 分級選擇器
            Picker("教學難度", selection: $selectedLevel) {
                ForEach(CoachLevel.allCases, id: \.self) { lvl in
                    Text(lvl.rawValue).tag(lvl)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .onChange(of: selectedLevel) {
                updateLesson()
            }

            Divider()

            // 教學內容區
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let cur = lesson {
                        // 策略標籤
                        HStack {
                            Text(cur.title)
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text(cur.strategyName)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ColorTheme.mintAccent.opacity(0.18))
                                .foregroundStyle(ColorTheme.mintAccent)
                                .cornerRadius(6)
                        }

                        // 數學條件
                        if !cur.mathematicalConditions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("📐 數學條件與邏輯前提")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.secondary)
                                ForEach(cur.mathematicalConditions, id: \.self) { cond in
                                    Text("• \(cond)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .padding(.leading, 8)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(10)
                        }

                        // 逐步推理過程
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🔍 逐步推導思維")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            ForEach(cur.stepByStepExplanation, id: \.self) { step in
                                Text(step)
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(10)

                        // 候選格風險比較
                        if !cur.candidateComparisons.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📊 候選位置風險對比")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.secondary)
                                ForEach(cur.candidateComparisons) { cand in
                                    HStack {
                                        Text("座標 (\(cand.coordinate.row), \(cand.coordinate.column))")
                                            .font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                        Text(cand.evaluationNote)
                                            .font(.system(size: 12))
                                            .foregroundStyle(cand.riskPercentage == 0.0 ? ColorTheme.mintAccent : (cand.riskPercentage == 100.0 ? Color.red : Color.orange))
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(10)
                        }

                        // 結論
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(ColorTheme.mintAccent)
                            Text(cur.conclusion)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTheme.mintAccent.opacity(0.12))
                        .cornerRadius(10)

                    } else {
                        ProgressView("教練正在分析棋盤...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button("關閉") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(16)
        }
        .frame(width: 540, height: 560)
        .background(ColorTheme.windowBackground(for: colorScheme))
        .onAppear {
            updateLesson()
        }
    }

    private func updateLesson() {
        let l = AIPuzzleCoach.shared.generateLesson(
            grid: engine.publicBoard(),
            totalMines: engine.internalBoard.totalMines,
            flaggedCount: engine.internalBoard.flaggedCount,
            level: selectedLevel
        )
        self.lesson = l
    }
}
