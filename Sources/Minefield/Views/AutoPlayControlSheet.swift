import SwiftUI

/// 自動排雷與自動遊玩控制面板 (Auto Play Sheet)
public struct AutoPlayControlSheet: View {
    public let engine: GameEngine
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var autoPlay = AutoPlayEngine.shared

    public init(engine: GameEngine, onDismiss: @escaping () -> Void) {
        self.engine = engine
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("AI 自動排雷與自動遊玩")
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

            Text("求解器依據純數學邏輯自動翻開必然安全格與標記必然地雷。\n遇到必須猜測之死局時將自動暫停，嚴格不偷看隱藏雷區。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()

            VStack(spacing: 18) {
                // 當前狀態指示
                HStack(spacing: 12) {
                    statusIcon
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.system(size: 15, weight: .bold))
                        Text("累計已執行排雷動作：\(autoPlay.stepsExecuted) 步")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(ColorTheme.cardBackground(for: colorScheme))
                .cornerRadius(10)

                // 速度切換
                VStack(alignment: .leading, spacing: 8) {
                    Text("推進速度")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    Picker("速度", selection: $autoPlay.speed) {
                        ForEach(AutoPlaySpeed.allCases) { sp in
                            Text(sp.title).tag(sp)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .background(ColorTheme.cardBackground(for: colorScheme))
                .cornerRadius(10)

                // 遇到猜測死局時的選項
                if case .pausedOnGuess(let cand) = autoPlay.state {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orange)
                            Text("遭遇純邏輯死局 (GUESS_REQUIRED)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        if let cand = cand {
                            Text("當前已無 100% 必然安全格。全盤最低地雷風險格為 (\(cand.row), \(cand.column)) (風險 \(Int(cand.risk * 100))%)。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("當前已無 100% 必然安全格。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button("使用 AI 救援並繼續") {
                                autoPlay.rescueAndContinue()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ColorTheme.mintAccent)

                            Button("停止自動排雷") {
                                autoPlay.stop()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                }

                Spacer()

                // 控制按鈕組
                HStack(spacing: 12) {
                    if autoPlay.state == .running {
                        Button("暫停") {
                            autoPlay.pause()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.orange)
                    } else if autoPlay.state == .paused {
                        Button("繼續") {
                            autoPlay.resume()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("開始連續排雷") {
                            autoPlay.start(engine: engine)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("單步排雷 (Step)") {
                        autoPlay.stepOnce(engine: engine)
                    }
                    .buttonStyle(.bordered)

                    if autoPlay.state == .running || autoPlay.state == .paused {
                        Button("停止") {
                            autoPlay.stop()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(Color.red)
                    }

                    Spacer()

                    Button("關閉") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 480)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private var statusIcon: some View {
        switch autoPlay.state {
        case .idle:
            return Image(systemName: "stop.circle.fill").foregroundStyle(Color.secondary)
        case .running:
            return Image(systemName: "bolt.horizontal.circle.fill").foregroundStyle(ColorTheme.mintAccent)
        case .paused:
            return Image(systemName: "pause.circle.fill").foregroundStyle(Color.orange)
        case .pausedOnGuess:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
        case .finishedWon:
            return Image(systemName: "checkmark.seal.fill").foregroundStyle(ColorTheme.mintAccent)
        case .finishedLost:
            return Image(systemName: "xmark.seal.fill").foregroundStyle(Color.red)
        }
    }

    private var statusTitle: String {
        switch autoPlay.state {
        case .idle: return "就緒待命"
        case .running: return "自動推理排雷中..."
        case .paused: return "已暫停"
        case .pausedOnGuess: return "遭遇猜測死局 (自動暫停)"
        case .finishedWon: return "🎉 棋局獲勝！"
        case .finishedLost: return "踩雷失敗"
        }
    }
}
