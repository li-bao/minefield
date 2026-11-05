import SwiftUI

/// 遊戲紀錄與統計儀表板 (Statistics Dashboard)
/// 依據遊戲模式嚴格隔離，沙盒模式不納入統計
public struct StatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMode: GameMode = .classic

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("戰績統計儀表板")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // 模式分類切換
            Picker("統計分類", selection: $selectedMode) {
                Text(GameMode.classic.rawValue).tag(GameMode.classic)
                Text(GameMode.noGuess.rawValue).tag(GameMode.noGuess)
                Text(GameMode.aiAssisted.rawValue).tag(GameMode.aiAssisted)
                Text(GameMode.aiRescue.rawValue).tag(GameMode.aiRescue)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            let stats = StatisticsService.shared.stats(forMode: selectedMode)

            ScrollView {
                VStack(spacing: 16) {
                    // 核心四大指標卡片
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricCard(title: "總遊玩場次", value: "\(stats.gamesPlayed)", subtitle: "獲勝: \(stats.gamesWon) ｜ 失敗: \(stats.gamesLost)")
                        metricCard(title: "總勝率", value: String(format: "%.1f%%", stats.winRate), subtitle: "最高連勝: \(stats.maxStreak) 場", valueColor: ColorTheme.mintAccent)
                        metricCard(title: "最佳通關時間", value: stats.bestTime.map { String(format: "%.1fs", $0) } ?? "--", subtitle: "平均時間: " + (stats.averageWinningTime > 0 ? String(format: "%.1fs", stats.averageWinningTime) : "--"))
                        metricCard(title: "踩雷次數", value: "\(stats.totalExplodedMines)", subtitle: "Undo 復原: \(stats.totalUndosUsed) 次", valueColor: stats.totalExplodedMines > 0 ? Color.orange : Color.primary)
                    }

                    // 輔助數據統計
                    VStack(alignment: .leading, spacing: 10) {
                        Text("輔助操作紀錄")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("智慧提示使用次數：")
                            Spacer()
                            Text("\(stats.totalHintsUsed) 次")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }

                        Divider()

                        HStack {
                            Text("AI 救援次數：")
                            Spacer()
                            Text("\(stats.totalAIRescuesUsed) 次")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }

                        Divider()

                        HStack {
                            Text("最常遊玩難度：")
                            Spacer()
                            Text(stats.mostPlayedDifficulty)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTheme.mintAccent)
                        }
                    }
                    .padding(16)
                    .background(ColorTheme.cardBackground(for: colorScheme))
                    .cornerRadius(10)
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("重設統計資料") {
                    StatisticsService.shared.resetAllStats()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.red)
                .controlSize(.small)

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 490)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private func metricCard(title: String, value: String, subtitle: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.cardBackground(for: colorScheme))
        .cornerRadius(10)
    }
}
