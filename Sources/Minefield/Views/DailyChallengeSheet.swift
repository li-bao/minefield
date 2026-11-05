import SwiftUI

/// 每日挑戰介面面板 (Daily Challenge Sheet)
public struct DailyChallengeSheet: View {
    public let onStartChallenge: (GameDifficulty, UInt64) -> Void
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var challengeInfo: DailyChallengeInfo?

    public init(
        onStartChallenge: @escaping (GameDifficulty, UInt64) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onStartChallenge = onStartChallenge
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("每日挑戰 (Daily Challenge)")
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

            Text("每日固定隨機種子，全球相同版本產生一致棋盤。\n純本機演算，完全支援離線遊玩與歷史留存。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()

            VStack(spacing: 16) {
                if let info = challengeInfo {
                    // 今日挑戰卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("📅 今日日期：\(info.dateString)")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            if info.isCompleted {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("今日已通關")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ColorTheme.mintAccent)
                            }
                        }

                        Divider()

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("挑戰難度")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(info.difficulty.title)
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("認證種子碼")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(String(info.seed, radix: 16, uppercase: true))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("無猜保證")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("✨ 100% 邏輯可解")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ColorTheme.mintAccent)
                            }
                        }
                    }
                    .padding(16)
                    .background(ColorTheme.cardBackground(for: colorScheme))
                    .cornerRadius(10)

                    // 過去最佳成果
                    if let past = info.pastRecord {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🏆 今日最佳通關成績")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("完成時間：\(String(format: "%.1f", past.completionTime)) 秒")
                                Spacer()
                                Text("提示: \(past.hintsUsed) 次 ｜ 救援: \(past.aiRescuesUsed) 次")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 13))
                        }
                        .padding(14)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(10)
                    }

                    Spacer()

                    // 開始按鈕
                    HStack {
                        Button(action: {
                            onStartChallenge(info.difficulty, info.seed)
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(info.isCompleted ? "重新挑戰今日棋盤" : "立即開始今日挑戰")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                } else {
                    ProgressView("載入挑戰資訊中...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 420)
        .background(ColorTheme.windowBackground(for: colorScheme))
        .onAppear {
            self.challengeInfo = DailyChallengeService.shared.todayChallenge()
        }
    }
}
