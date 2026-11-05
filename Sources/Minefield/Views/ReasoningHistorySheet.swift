import SwiftUI

/// 完整推理視覺化展開歷程視窗 (Reasoning History Visualizer)
public struct ReasoningHistorySheet: View {
    @ObservedObject public var historyManager: ReasoningHistoryManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(historyManager: ReasoningHistoryManager = .shared) {
        self.historyManager = historyManager
    }

    public var body: some View {
        VStack(spacing: 20) {
            // 標題列
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTheme.indigoAccent)
                    Text("推理與防猜歷史視覺化")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                Button("清空歷程") {
                    historyManager.clear()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Button("關閉") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
            }

            if historyManager.history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("尚無推理紀錄")
                        .font(.system(size: 15, weight: .medium))
                    Text("點擊「智慧排雷」、「提示」或進行棋盤自動防猜修復時，將在此逐步展示推導鏈。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(historyManager.history) { step in
                            reasoningCard(step)
                        }
                    }
                }
            }
        }
        .padding(26)
        .frame(width: 540, height: 600)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    @ViewBuilder
    private func reasoningCard(_ step: ReasoningStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 推理方法標籤
                Text(step.method)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(ColorTheme.indigoAccent.opacity(0.18))
                    )
                    .foregroundStyle(ColorTheme.indigoAccent)

                // 結果類型標籤
                Text(step.resultType)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(resultBadgeColor(step.resultType).opacity(0.18))
                    )
                    .foregroundStyle(resultBadgeColor(step.resultType))

                if step.wasRepaired {
                    Text("棋盤已微調")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ColorTheme.amberWarning.opacity(0.2)))
                        .foregroundStyle(ColorTheme.amberWarning)
                }

                Spacer()

                Text(step.timestamp, style: .time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(step.detail)
                .font(.system(size: 13))
                .lineSpacing(2)

            if let target = step.targetCell {
                HStack(spacing: 12) {
                    Text("目標格: (\(target.row), \(target.column))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))

                    if let risk = step.riskPercentage {
                        Text("地雷風險: \(String(format: "%.1f%%", risk * 100))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(risk == 0.0 ? ColorTheme.mintAccent : ColorTheme.amberWarning)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.cardBackground(for: colorScheme))
        )
    }

    private func resultBadgeColor(_ type: String) -> Color {
        switch type {
        case "必然安全": return ColorTheme.mintAccent
        case "必然地雷": return ColorTheme.amberWarning
        case "需要猜測": return Color(red: 0.96, green: 0.62, blue: 0.15)
        case "棋盤已修復": return ColorTheme.mintAccent
        default: return .secondary
        }
    }
}
