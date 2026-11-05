import SwiftUI

/// AI 專家問答聊天室面板 (AI Assistant Chat Sheet)
public struct AIChatPanelSheet: View {
    public let engine: GameEngine
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var chatService = AIChatAssistantService.shared
    @State private var inputPrompt: String = ""

    private let quickPrompts = [
        "為什麼推薦的位置是安全的？",
        "目前盤面哪一格地雷風險最低？",
        "我現在一定要猜測嗎？",
        "有沒有更好的下一步決策？",
        "請解釋這一步背後的數學推理。"
    ]

    public init(engine: GameEngine, onDismiss: @escaping () -> Void) {
        self.engine = engine
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("AI 專家局勢問答室")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: {
                    chatService.clearMessages()
                }) {
                    Text("清除對話")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

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

            Text("詢問當前盤面局勢。AI 自然語言解盤由內建 CSP 求解器提供客觀依據，嚴格不偷看隱藏雷區。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            Divider()

            // 對話訊息滾動區
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatService.messages) { msg in
                            HStack(alignment: .top, spacing: 10) {
                                if msg.sender == .assistant {
                                    Image(systemName: "cpu.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(ColorTheme.mintAccent)
                                        .padding(.top, 4)
                                } else {
                                    Spacer()
                                }

                                VStack(alignment: msg.sender == .user ? .trailing : .leading, spacing: 6) {
                                    Text(msg.text)
                                        .font(.system(size: 13))
                                        .padding(12)
                                        .background(msg.sender == .user ? ColorTheme.mintAccent.opacity(0.2) : ColorTheme.cardBackground(for: colorScheme))
                                        .cornerRadius(12)

                                    if let ev = msg.solverEvidence {
                                        Text(ev)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                }

                                if msg.sender == .user {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                } else {
                                    Spacer()
                                }
                            }
                            .id(msg.id)
                        }

                        if chatService.isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("AI 正在根據求解器資料進行推理解析...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: chatService.messages.count) {
                    if let last = chatService.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 快捷提問晶片按鈕列
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button(action: {
                            chatService.sendQuestion(
                                prompt,
                                grid: engine.publicBoard(),
                                totalMines: engine.internalBoard.totalMines,
                                flaggedCount: engine.internalBoard.flaggedCount
                            )
                        }) {
                            Text(prompt)
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ColorTheme.cardBackground(for: colorScheme))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(chatService.isGenerating)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(ColorTheme.cardBackground(for: colorScheme).opacity(0.5))

            Divider()

            // 輸入文字列
            HStack(spacing: 10) {
                TextField("輸入關於當前棋局的疑問...", text: $inputPrompt)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitInput()
                    }

                if chatService.isGenerating {
                    Button("停止") {
                        chatService.stopGenerating()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("發送") {
                        submitInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 580, height: 560)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private func submitInput() {
        let q = inputPrompt.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        inputPrompt = ""
        chatService.sendQuestion(
            q,
            grid: engine.publicBoard(),
            totalMines: engine.internalBoard.totalMines,
            flaggedCount: engine.internalBoard.flaggedCount
        )
    }
}
