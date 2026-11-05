import SwiftUI

/// 遊戲主選單畫面 (Phase 4.75 全功能主導航)
public struct MainMenuView: View {
    @Environment(\.colorScheme) private var colorScheme

    public let onSelectDifficulty: (GameDifficulty) -> Void
    public let onOpenCustomSheet: () -> Void
    public let onOpenDailyChallenge: () -> Void
    public let onOpenSandbox: () -> Void
    public let onOpenTutorial: () -> Void
    public let onOpenAchievements: () -> Void
    public let onOpenStats: () -> Void
    public let onOpenSettings: () -> Void

    public init(
        onSelectDifficulty: @escaping (GameDifficulty) -> Void,
        onOpenCustomSheet: @escaping () -> Void,
        onOpenDailyChallenge: @escaping () -> Void,
        onOpenSandbox: @escaping () -> Void,
        onOpenTutorial: @escaping () -> Void,
        onOpenAchievements: @escaping () -> Void,
        onOpenStats: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onSelectDifficulty = onSelectDifficulty
        self.onOpenCustomSheet = onOpenCustomSheet
        self.onOpenDailyChallenge = onOpenDailyChallenge
        self.onOpenSandbox = onOpenSandbox
        self.onOpenTutorial = onOpenTutorial
        self.onOpenAchievements = onOpenAchievements
        self.onOpenStats = onOpenStats
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo 與標題品牌區
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ColorTheme.indigoAccent,
                                    Color(red: 0.12, green: 0.14, blue: 0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: ColorTheme.indigoAccent.opacity(0.35), radius: 14, x: 0, y: 6)

                    Image(systemName: "flag.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTheme.mintAccent)
                }

                VStack(spacing: 4) {
                    Text("Minefield")
                        .font(.system(size: 34, weight: .black, design: .rounded))

                    Text("Apple Silicon 原生現代掃雷遊戲")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // 主要難度開始區
            HStack(spacing: 12) {
                DifficultyPill(title: "初級 (9×9)", icon: "leaf.fill", color: ColorTheme.mintAccent) {
                    onSelectDifficulty(.beginner)
                }
                DifficultyPill(title: "中級 (16×16)", icon: "flame.fill", color: Color.blue) {
                    onSelectDifficulty(.intermediate)
                }
                DifficultyPill(title: "高級 (30×16)", icon: "bolt.fill", color: Color.orange) {
                    onSelectDifficulty(.expert)
                }
                DifficultyPill(title: "自訂棋盤", icon: "slider.horizontal.3", color: ColorTheme.indigoAccent) {
                    onOpenCustomSheet()
                }
            }
            .frame(maxWidth: 580)

            Divider().frame(width: 380).padding(.vertical, 4)

            // 特色遊戲模式與實驗室功能群
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    FeatureCard(
                        title: "每日挑戰",
                        subtitle: "今日限定種子 · 獨立排行",
                        icon: "calendar.badge.clock",
                        color: Color.purple,
                        action: onOpenDailyChallenge
                    )

                    FeatureCard(
                        title: "沙盒實驗室",
                        subtitle: "自由擺設 · 演算模擬驗證",
                        icon: "wrench.and.screwdriver.fill",
                        color: Color.blue,
                        action: onOpenSandbox
                    )
                }

                HStack(spacing: 12) {
                    FeatureCard(
                        title: "互動排雷教學",
                        subtitle: "新手引導 · 集合推理掌握",
                        icon: "book.fill",
                        color: ColorTheme.mintAccent,
                        action: onOpenTutorial
                    )

                    FeatureCard(
                        title: "成就榮譽榜",
                        subtitle: "解鎖徽章 · 實力見證",
                        icon: "trophy.fill",
                        color: Color.yellow,
                        action: onOpenAchievements
                    )
                }
            }
            .frame(width: 480)

            // 底部輔助按鈕 (戰績、偏好設定)
            HStack(spacing: 16) {
                Button(action: onOpenStats) {
                    Label("戰績統計", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Text("·").foregroundStyle(.secondary)

                Button(action: onOpenSettings) {
                    Label("系統設定", systemImage: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 6)

            Spacer()

            Text("Phase 4.75 終極功能版 · Apple Silicon ARM64 原生")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }
}

private struct DifficultyPill: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTheme.cardBackground(for: colorScheme))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? color.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(isHovered ? 0.25 : 0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(ColorTheme.cardBackground(for: colorScheme))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? color.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
