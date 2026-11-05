import Foundation

/// 本機 Ollama AI 棋局修復輔助顧問
/// 負責向 LLM 徵詢微調策略建議，並提交給 BoardRepairEngine 進行硬性交易審查
public final class AIBoardRepairAssistant: Sendable {
    public static let shared = AIBoardRepairAssistant()

    private let ollama: OllamaService
    private let repairEngine: BoardRepairEngine

    public init(
        ollama: OllamaService = OllamaService.shared,
        repairEngine: BoardRepairEngine = BoardRepairEngine.shared
    ) {
        self.ollama = ollama
        self.repairEngine = repairEngine
    }

    /// 向 Ollama 請求修復方案並交由引擎驗證
    public func requestAIRepair(
        board: Board,
        solverResult: SolverResult,
        host: String,
        model: String,
        timeout: TimeInterval = 25.0
    ) async throws -> (rawAI: RawAIRepairResponse, validatedResult: BoardRepairResult) {
        let systemPrompt = """
        你是一位精通掃雷 (Minesweeper) 數學最佳化與拓撲結構修復的專家。
        目前棋盤陷入猜測死局 (GUESS_REQUIRED)。
        請分析局面的約束，並提出「最小地雷移動量 (Minimal Change)」修復方案以打破對稱性。
        嚴格規則：
        1. 只能移動尚未翻開的隱藏地雷至其他未翻開的空格中。
        2. 絕對不可將地雷移入已經翻開的格子。
        3. 必須保證所有已翻開格子的周圍地雷總數 100% 保持原值不變！
        4. 總地雷數必須嚴格守恆。
        5. 必須嚴格輸出 JSON 格式 (繁體中文)，不得有額外註解或 Markdown 標籤。
        JSON Schema：
        {
          "analysis": "簡述為何陷入猜測死局",
          "repair_strategy": "minimal_change",
          "reasoning": "移動地雷的拓撲學理由",
          "constraints": ["保持已翻開格數字一致"],
          "suggestions": [
            { "fromRow": 1, "fromCol": 2, "toRow": 0, "toCol": 5 }
          ]
        }
        """

        var frontierText = ""
        for (coordKey, prob) in solverResult.probabilities {
            if prob.mineProbability > 0.0 && prob.mineProbability < 1.0 {
                frontierText += "未知格 \(coordKey): 地雷機率 \(String(format: "%.1f%%", prob.mineProbability * 100))\n"
            }
        }

        let userPrompt = """
        【當前局勢】: \(solverResult.summary)
        【不確定格機率分佈】:
        \(frontierText.isEmpty ? "局部對稱死局" : frontierText)
        請給出打破猜測僵局的最小修改建議。
        """

        let messages = [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: userPrompt)
        ]

        let responseContent = try await ollama.chat(
            host: host,
            model: model,
            messages: messages,
            timeout: timeout
        )

        let rawAI = try parseAIRepairResponse(responseContent)

        // 將 AI 建議交由 BoardRepairEngine 進行硬性數學審查與回滾機制驗證
        let validated = repairEngine.validateAndApplyAIRepair(currentBoard: board, aiPlan: rawAI)

        return (rawAI, validated)
    }

    private func parseAIRepairResponse(_ content: String) throws -> RawAIRepairResponse {
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```") {
            let lines = jsonString.components(separatedBy: "\n")
            let cleanedLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            jsonString = cleanedLines.joined(separator: "\n")
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw OllamaError.decodingFailed("無法將文字轉換為 UTF-8 格式")
        }

        do {
            return try JSONDecoder().decode(RawAIRepairResponse.self, from: data)
        } catch {
            throw OllamaError.decodingFailed("AI 修復建議 JSON 結構無效: \(error.localizedDescription)")
        }
    }
}
