import SwiftUI

/// 全盤風險熱力圖與資訊價值排序視圖 (Risk Heatmap Sheet)
public struct RiskHeatmapSheet: View {
    public let engine: GameEngine
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var theme = ThemeManager.shared
    @State private var report: HeatmapReport?

    public init(engine: GameEngine, onDismiss: @escaping () -> Void) {
        self.engine = engine
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.orange)
                    .font(.system(size: 20))
                Text("高級機率與風險熱力圖")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Toggle("色盲友善模式", isOn: $theme.colorblindMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
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

            // 圖例說明條
            HStack(spacing: 12) {
                LegendPill(color: riskColor(0.0), label: "0% 安全")
                LegendPill(color: riskColor(0.2), label: "<25% 低風險")
                LegendPill(color: riskColor(0.5), label: "25~60% 中度")
                LegendPill(color: riskColor(0.8), label: ">60% 高危險")
                LegendPill(color: riskColor(1.0), label: "100% 地雷")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let rep = report {
                        // 1. 最推薦的下一步
                        if let rec = rep.recommendedMove {
                            HStack(spacing: 12) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(ColorTheme.mintAccent)
                                    .font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("演算法最推薦下一步：座標 (\(rec.coordinate.row), \(rec.coordinate.column))")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("地雷機率: \(String(format: "%.1f", rec.probability * 100))% ｜ 計算依據: \(rec.computationMethod) ｜ 消除不確定性 (資訊熵): \(String(format: "%.2f", rec.informationGain))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.mintAccent.opacity(0.12))
                            .cornerRadius(10)
                        }

                        // 2. 最安全格子列表 (Top 5)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🛡️ 最安全候選格 (最低地雷風險)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            ForEach(rep.safestCells.prefix(5)) { item in
                                HStack {
                                    Text("座標 (\(item.coordinate.row), \(item.coordinate.column))")
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text(item.computationMethod)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text("\(String(format: "%.1f", item.probability * 100))%")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(riskColor(item.probability))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(10)

                        // 3. 最大資訊價值格 (Top 5 Highest Information Gain)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 最佳資訊價值格 (揭露後能消除最多未知數)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            ForEach(rep.bestInfoGainCells.prefix(5)) { item in
                                HStack {
                                    Text("座標 (\(item.coordinate.row), \(item.coordinate.column))")
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text("資訊熵: \(String(format: "%.2f", item.informationGain))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text("風險 \(String(format: "%.1f", item.probability * 100))%")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(riskColor(item.probability))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(10)

                    } else {
                        ProgressView("正在精算全盤連通分支組合機率...")
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
            }
            .padding(16)
        }
        .frame(width: 540, height: 560)
        .background(ColorTheme.windowBackground(for: colorScheme))
        .onAppear {
            calculateReport()
        }
    }

    private func calculateReport() {
        let r = ProbabilityCalculator.shared.generateHeatmap(
            grid: engine.publicBoard(),
            totalMines: engine.internalBoard.totalMines,
            flaggedCount: engine.internalBoard.flaggedCount
        )
        self.report = r
    }

    private func riskColor(_ p: Double) -> Color {
        if theme.colorblindMode {
            // 色盲友善 (藍色安全 -> 琥珀中等 -> 洋紅極危險)
            if abs(p) < 1e-6 { return Color.blue }
            if p <= 0.25 { return Color.cyan }
            if p <= 0.60 { return Color.yellow }
            if p < 1.0 { return Color.orange }
            return Color.purple
        } else {
            // 標準熱力
            if abs(p) < 1e-6 { return ColorTheme.mintAccent }
            if p <= 0.25 { return Color.teal }
            if p <= 0.60 { return Color.yellow }
            if p < 1.0 { return Color.orange }
            return Color.red
        }
    }
}

private struct LegendPill: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
    }
}
