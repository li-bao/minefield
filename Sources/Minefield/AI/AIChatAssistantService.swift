import Foundation
import Combine

/// 對話發送者
public enum ChatSender: String, Codable, Sendable {
    case user = "玩家"
    case assistant = "AI 專家教練"
}

/// AI 對話訊息實體
public struct AIChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sender: ChatSender
    public let text: String
    public let timestamp: Date
    public let solverEvidence: String?

    public init(
        id: UUID = UUID(),
        sender: ChatSender,
        text: String,
        timestamp: Date = Date(),
        solverEvidence: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.solverEvidence = solverEvidence
    }
}

/// AI 專家互動聊天助手服務
@MainActor
public final class AIChatAssistantService: ObservableObject {
    public static let shared = AIChatAssistantService()

    @Published public private(set) var messages: [AIChatMessage] = []
    @Published public private(set) var isGenerating: Bool = false
    @Published public var selectedModel: String = "llama3:latest"

    private var currentTask: Task<Void, Never>?

    public init() {
        self.messages = [
            AIChatMessage(
                sender: .assistant,
                text: "你好！我是你的 Minefield AI 戰術解盤教練。你可以點選下方快捷提問，或直接詢問當前盤面的推理邏輯與風險。",
                solverEvidence: "系統已就緒，所有數學推導由內建 CSP 求解器雙重校驗。"
            )
        ]
    }

    /// 發送使用者提問並結合 Solver 依據取得解答
    public func sendQuestion(
        _ questionText: String,
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int
    ) {
        let userMsg = AIChatMessage(sender: .user, text: questionText)
        messages.append(userMsg)

        // 求解器客觀數學分析作為依據 (Ground Truth)
        let solverResult = SmartSolver.shared.analyze(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount)
        let heatmap = ProbabilityCalculator.shared.generateHeatmap(grid: grid, totalMines: totalMines, flaggedCount: flaggedCount, solverResult: solverResult)

        isGenerating = true

        currentTask = Task { [weak self] in
            guard let self = self else { return }

            // 結構化事實資料
            let lowestRiskDesc = solverResult.lowestRiskCells.first.map { "(\($0.row), \($0.column)) 風險 \(Int($0.risk * 100))%" } ?? "無"
            let evidenceSummary = "【內建求解器客觀真值】盤面狀態: \(solverResult.status.rawValue)。確定安全格: \(solverResult.sureSafeCells.count) 個。確定地雷: \(solverResult.sureMineCells.count) 顆。最低風險格: \(lowestRiskDesc)。"

            // 嘗試透過本地 Ollama 生成更生動的自然語言對話
            let systemPrompt = """
            你是一位專業的 macOS 掃雷遊戲教練。請使用親切、繁體中文回答玩家關於當前棋盤的提問。
            你必須遵守以下規則：
            1. 絕對信任並引用求解器提供的客觀真值。不得虛構不存在的安全格。
            2. 若盤面需要猜測，明確承認當前局勢的不確定性。
            3. 解釋背後的數學或邏輯思維 (例如集合包含、CSP 或相鄰相減)。
            4. 回覆簡潔清晰，分段說明。
            """

            let recommendedDesc = solverResult.recommendedMove.map { "(\($0.row), \($0.column)) - \($0.action.rawValue) (理由: \($0.reason))" } ?? "暫無"
            let boardDescription = """
            棋盤公開資訊：
            - 總地雷數: \(totalMines)，已插旗: \(flaggedCount)
            - 求解器狀態: \(solverResult.status.rawValue)
            - 推薦下一步: \(recommendedDesc)
            - 客觀地雷機率最低候選: \(solverResult.lowestRiskCells.map { "(\($0.row), \($0.column)): \(Int($0.risk * 100))%" }.joined(separator: ", "))
            """

            let prompt = "\(boardDescription)\n\n玩家提問：\(questionText)\n\n請根據以上客觀資訊回答："

            let host = AppSettingsManager.shared.ollamaHost
            let chatMessages = [
                OllamaChatMessage(role: "system", content: systemPrompt),
                OllamaChatMessage(role: "user", content: prompt)
            ]

            do {
                let response = try await OllamaService.shared.chat(
                    host: host,
                    model: self.selectedModel,
                    messages: chatMessages,
                    timeout: 20.0
                )

                if !Task.isCancelled {
                    let aiMsg = AIChatMessage(
                        sender: .assistant,
                        text: response,
                        solverEvidence: evidenceSummary
                    )
                    self.messages.append(aiMsg)
                }
            } catch {
                // 本地 Ollama 離線時之確定性數學回覆 (優雅降級)
                if !Task.isCancelled {
                    let fallbackAnswer = self.buildDeterministicAnswer(
                        question: questionText,
                        solverResult: solverResult,
                        heatmap: heatmap
                    )
                    let aiMsg = AIChatMessage(
                        sender: .assistant,
                        text: fallbackAnswer,
                        solverEvidence: evidenceSummary + " (本地 Ollama 服務未啟動，已切換至內建數學規則回答)"
                    )
                    self.messages.append(aiMsg)
                }
            }

            self.isGenerating = false
        }
    }

    /// 停止生成
    public func stopGenerating() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    /// 清除對話紀錄
    public func clearMessages() {
        stopGenerating()
        messages.removeAll()
    }

    // MARK: - 確定性離線回覆產生器
    private func buildDeterministicAnswer(
        question: String,
        solverResult: SolverResult,
        heatmap: HeatmapReport
    ) -> String {
        if question.contains("安全") {
            if let safe = solverResult.sureSafeCells.first {
                return "根據相鄰約束與集合包含推理，座標 (\(safe.row), \(safe.column)) 目前已完全排除有雷的可能，其地雷機率嚴格為 0.0%，因此是必然安全的！"
            } else {
                return "當前盤面經窮舉二元配置後，所有未翻開格子皆存在非零的地雷機率，目前沒有 100% 必然安全的位置。"
            }
        } else if question.contains("風險最低") {
            if let rec = heatmap.safestCells.first {
                return "經 CSP 分群枚舉計算，全盤地雷風險最低的位置是座標 (\(rec.coordinate.row), \(rec.coordinate.column))，地雷機率約為 \(String(format: "%.1f", rec.probability * 100.0))%。"
            } else {
                return "目前所有未知區域風險均等，或尚未有已翻開的數字可供推導。"
            }
        } else if question.contains("猜測") {
            if solverResult.status == .guessRequired {
                return "是的，當前盤面已經陷入純邏輯死局 (GUESS_REQUIRED)。現有已知數字無法進一步推導出確定解，必須在候選格中進行機率抉擇，或使用 AI 救援 / 棋盤修復。"
            } else {
                return "不需要猜測！當前盤面依然存在 \(solverResult.sureSafeCells.count) 個必然安全格與 \(solverResult.sureMineCells.count) 顆確定地雷，可以依靠純邏輯繼續推進。"
            }
        } else {
            return "針對當前局勢：內建求解器狀態為「\(solverResult.status.rawValue)」。建議操作：\(solverResult.recommendedMove?.reason ?? solverResult.summary)。"
        }
    }
}
