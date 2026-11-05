import SwiftUI

/// 新手與進階互動教學面板視圖 (Tutorial Sheet)
public struct TutorialSheet: View {
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = TutorialManager.shared

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("新手與進階互動排雷教學")
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

            Divider()

            if let active = manager.activeCourse {
                // 課程進行中
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(active.title)
                                .font(.system(size: 15, weight: .bold))
                            Text("步驟 \(manager.currentStepIndex + 1) / \(active.steps.count)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("返回課程清單") {
                            manager.finishCourse()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let step = manager.currentStep {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(step.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(ColorTheme.mintAccent)
                                Spacer()
                                Text("預期操作：\(step.expectedAction)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ColorTheme.mintAccent.opacity(0.15))
                                    .cornerRadius(6)
                            }

                            Text(step.instruction)
                                .font(.system(size: 14))

                            if let target = step.targetCoordinate {
                                Text("🎯 目標方格座標：(\(target.row), \(target.column))")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.orange)
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Color.yellow)
                                Text(step.tipNote)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(8)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(12)
                    }

                    Spacer()

                    // 控制按鈕
                    HStack {
                        Button("上一步") {
                            manager.previousStep()
                        }
                        .buttonStyle(.bordered)
                        .disabled(manager.currentStepIndex == 0)

                        Spacer()

                        if manager.currentStepIndex < active.steps.count - 1 {
                            Button("下一步") {
                                manager.nextStep()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("完成本單元教學") {
                                manager.finishCourse()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(24)

            } else {
                // 課程清單
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(manager.courses) { course in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(ColorTheme.mintAccent.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "lightbulb.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(ColorTheme.mintAccent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(course.title)
                                            .font(.system(size: 14, weight: .bold))
                                        Spacer()
                                        Text(course.category)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    Text(course.summary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Button("開始學習") {
                                    manager.startCourse(course)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(14)
                            .background(ColorTheme.cardBackground(for: colorScheme))
                            .cornerRadius(10)
                        }
                    }
                    .padding(24)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("關閉") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }
}
