import Combine
import SwiftUI

/// 遊戲頂部資訊控制列 (難度、計雷器、表情重新開始按鈕、計時器)
public struct GameHeaderView: View {
    @ObservedObject public var engine: GameEngine
    public let onOpenSettings: () -> Void
    public let onBackToMenu: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var timerNow = Date()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    public init(
        engine: GameEngine,
        onOpenSettings: @escaping () -> Void,
        onBackToMenu: @escaping () -> Void
    ) {
        self.engine = engine
        self.onOpenSettings = onOpenSettings
        self.onBackToMenu = onBackToMenu
    }

    public var body: some View {
        HStack(spacing: 16) {
            // 左側：回選單 + 難度標籤 + 地雷倒數
            HStack(spacing: 12) {
                Button(action: onBackToMenu) {
                    Label("主選單", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )

                // 地雷剩餘計數器
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTheme.amberWarning)
                    Text("\(engine.remainingMinesToFlag)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .frame(minWidth: 32)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.cardBackground(for: colorScheme))
                )
            }

            Spacer()

            // 中央：狀態臉部按鈕 (點擊立即重新開始)
            Button(action: {
                engine.restartCurrentGame()
            }) {
                statusFaceIcon
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ColorTheme.cardBackground(for: colorScheme))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("點擊重新開始此棋局")

            Spacer()

            // 右側：計時器與懲罰顯示 + 設定按鈕
            HStack(spacing: 12) {
                // 計時器
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTheme.mintAccent)

                    Text(formattedTime(engine.totalTimeWithPenalties))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .frame(minWidth: 54)

                    if engine.explodedMineCount > 0 {
                        Text("+\(Int(Double(engine.explodedMineCount) * engine.penaltySecondsPerMine))s")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ColorTheme.crimsonExplosion)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ColorTheme.crimsonExplosion.opacity(0.15))
                            )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.cardBackground(for: colorScheme))
                )

                // 設定按鈕
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )
                .help("遊戲設定")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ColorTheme.elevatedCardBackground(for: colorScheme).opacity(0.9)
        )
        .overlay(
            Divider(), alignment: .bottom
        )
        .onReceive(timer) { _ in
            timerNow = Date()
        }
    }

    @ViewBuilder
    private var statusFaceIcon: some View {
        switch engine.state {
        case .ready, .inProgress:
            if engine.explodedMineCount > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTheme.amberWarning)
            } else {
                Image(systemName: "face.smiling.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
            }
        case .won:
            Image(systemName: "trophy.fill")
                .foregroundStyle(ColorTheme.amberWarning)
        case .lost:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(ColorTheme.crimsonExplosion)
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
