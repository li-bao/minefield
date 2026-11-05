import SwiftUI

/// 成就系統展示面板 (Achievements Sheet)
public struct AchievementsSheet: View {
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = AchievementManager.shared

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.yellow)
                    .font(.system(size: 20))
                Text("成就榮譽榜")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("已解鎖 \(unlockedCount) / \(manager.achievements.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
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

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(manager.achievements) { ach in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(ach.isUnlocked ? Color.yellow.opacity(0.18) : Color.gray.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: ach.iconName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(ach.isUnlocked ? Color.yellow : Color.secondary.opacity(0.5))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(ach.title)
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    if ach.isUnlocked {
                                        Text("已解鎖")
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(ColorTheme.mintAccent.opacity(0.15))
                                            .foregroundStyle(ColorTheme.mintAccent)
                                            .cornerRadius(4)
                                    } else {
                                        Text("未解鎖")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(ach.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(10)
                        .opacity(ach.isUnlocked ? 1.0 : 0.6)
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
        .frame(width: 520, height: 560)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private var unlockedCount: Int {
        manager.achievements.filter { $0.isUnlocked }.count
    }
}
