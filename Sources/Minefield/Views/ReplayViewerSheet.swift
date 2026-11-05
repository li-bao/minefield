import SwiftUI

/// 棋局回放檢視器面板 (Replay Viewer Sheet)
public struct ReplayViewerSheet: View {
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engine = ReplayEngine.shared

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題列
            HStack {
                Image(systemName: "film.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("棋局完整歷史回放 (Replay)")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: {
                    engine.pause()
                    onDismiss()
                }) {
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

            if let current = engine.currentStep {
                // 回放棋盤預覽
                VStack(spacing: 12) {
                    // 資訊條
                    HStack {
                        Text("步驟 \(current.stepIndex + 1) / \(engine.totalSteps)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("動作：\(current.actionType.rawValue)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTheme.mintAccent.opacity(0.18))
                            .foregroundStyle(ColorTheme.mintAccent)
                            .cornerRadius(6)
                        Text("時間: \(String(format: "%.1f", current.timestamp))s")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(current.description)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 簡化網格縮影展示
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 2) {
                            ForEach(0..<current.boardSnapshot.rows, id: \.self) { r in
                                HStack(spacing: 2) {
                                    ForEach(0..<current.boardSnapshot.columns, id: \.self) { c in
                                        let cell = current.boardSnapshot[r, c]
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(cellBg(cell))
                                                .frame(width: 22, height: 22)
                                            if cell.state == .revealed {
                                                if cell.neighboringMines > 0 {
                                                    Text("\(cell.neighboringMines)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color.white)
                                                }
                                            } else if cell.state == .flagged {
                                                Image(systemName: "flag.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(Color.yellow)
                                            } else if cell.state == .exploded {
                                                Image(systemName: "burst.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(Color.red)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(8)
                    }
                    .frame(height: 240)
                }
                .padding(20)

                Divider()

                // 控制列 (播放、暫停、前後步、進度滑桿)
                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { Double(engine.currentStepIndex) },
                            set: { engine.seek(toStep: Int($0)) }
                        ),
                        in: 0...Double(max(0, engine.totalSteps - 1)),
                        step: 1.0
                    )

                    HStack(spacing: 16) {
                        Button(action: { engine.stepBackward() }) {
                            Image(systemName: "backward.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            if engine.isPlaying {
                                engine.pause()
                            } else {
                                engine.play()
                            }
                        }) {
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { engine.stepForward() }) {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Picker("倍速", selection: $engine.playbackSpeed) {
                            Text("0.5x").tag(0.5)
                            Text("1.0x").tag(1.0)
                            Text("2.0x").tag(2.0)
                            Text("4.0x").tag(4.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)

            } else {
                VStack(spacing: 10) {
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("當前局盤尚無可回放之歷史步驟。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 580, height: 500)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private func cellBg(_ cell: Cell) -> Color {
        switch cell.state {
        case .hidden: return Color.gray.opacity(0.3)
        case .revealed: return Color.gray.opacity(0.15)
        case .flagged: return Color.yellow.opacity(0.2)
        case .exploded: return Color.red.opacity(0.35)
        }
    }
}
