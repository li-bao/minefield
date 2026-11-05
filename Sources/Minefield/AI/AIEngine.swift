import Foundation

/// 負責整合本機 Ollama AI 與 SmartSolver 之智慧中樞
/// 實作嚴格的程式端安全驗證防護，杜絕 AI 越權或假推導
public final class AIEngine {
    public static let shared = AIEngine()

    private let solver: SolverProtocol
    private let ollama: OllamaService

    public init(
        solver: SolverProtocol = SmartSolver.shared,
        ollama: OllamaService = OllamaService.shared
    ) {
        self.solver = solver
        self.ollama = ollama
    }

    /// 執行 AI 專家分析 (純非同步，不凍結 UI)
    public func analyzeBoardWithAI(
        grid: [[PublicCell]],
        totalMines: Int,
        flaggedCount: Int,
        host: String,
        model: String,
        timeout: TimeInterval = 25.0
    ) async throws -> ValidatedAIAnalysis {
        let rows = grid.count
        guard rows > 0 else {
            throw OllamaError.emptyResponse
        }
        let cols = grid[0].count

        // 1. 先執行數學 CSP Solver 取得客觀機率真值
        let solverResult = solver.analyze(
            grid: grid,
            totalMines: totalMines,
            flaggedCount: flaggedCount
        )

        // 2. 準備向 AI 提供的棋盤公開情資 (僅包含已翻開的數字格與鄰近關係)
        let promptPayload = buildPromptPayload(
            grid: grid,
            rows: rows,
            cols: cols,
            totalMines: totalMines,
            flaggedCount: flaggedCount,
            solverResult: solverResult
        )

        let systemPrompt = """
        你是一位精通掃雷 (Minesweeper) 命題邏輯、集合論與約束滿足問題 (CSP) 的 AI 特級專家。
        請根據使用者提供的目前公開棋盤狀態進行深度局勢剖析。
        規則與約束：
        1. 必須全程使用繁體中文 (Traditional Chinese)。
        2. 只能針對尚未翻開的格子 (hidden) 提出建議，絕對不可建議已翻開或已插旗的格子。
        3. 必須嚴格輸出合法的 JSON 物件，不得夾帶額外文字或 markdown 標籤。
        JSON Schema 範例：
        {
          "summary": "以繁體中文綜合評估目前局盤",
          "status": "safe" | "mine" | "guess_required",
          "suggestions": [
            {
              "row": 2,
              "column": 3,
              "action": "reveal" | "flag" | "guess",
              "reason": "詳細繁體中文推理依據",
              "confidence": 90
            }
          ]
        }
        """

        let messages = [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: promptPayload)
        ]

        // 3. 非同步呼叫 Ollama API
        let responseContent = try await ollama.chat(
            host: host,
            model: model,
            messages: messages,
            timeout: timeout
        )

        // 4. 解析模型輸出的 JSON
        let rawResponse = try parseRawAIResponse(responseContent)

        // 5. 執行關鍵防護驗證 (AI Safety Validation)
        let validatedSuggestions = validateAISuggestions(
            rawSuggestions: rawResponse.suggestions,
            grid: grid,
            rows: rows,
            cols: cols,
            solverResult: solverResult
        )

        return ValidatedAIAnalysis(
            summary: rawResponse.summary,
            modelName: model,
            suggestions: validatedSuggestions,
            solverStatus: solverResult.status,
            timestamp: Date()
        )
    }

    // MARK: - 構建 Prompt Payload (僅包含公開資訊)
    private func buildPromptPayload(
        grid: [[PublicCell]],
        rows: Int,
        cols: Int,
        totalMines: Int,
        flaggedCount: Int,
        solverResult: SolverResult
    ) -> String {
        var frontierList: [String] = []

        for r in 0..<rows {
            for c in 0..<cols {
                let cell = grid[r][c]
                if cell.isRevealed, let num = cell.neighboringMines, num > 0 {
                    var hiddenNeighbors: [String] = []
                    var flaggedNeighbors: [String] = []

                    for dr in -1...1 {
                        for dc in -1...1 {
                            if dr == 0 && dc == 0 { continue }
                            let nr = r + dr
                            let nc = c + dc
                            if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                                let n = grid[nr][nc]
                                if n.isHidden {
                                    hiddenNeighbors.append("(\(nr),\(nc))")
                                } else if n.isFlagged {
                                    flaggedNeighbors.append("(\(nr),\(nc))")
                                }
                            }
                        }
                    }

                    if !hiddenNeighbors.isEmpty {
                        frontierList.append(
                            "格子(\(r),\(c))數字=\(num)，已插旗:\(flaggedNeighbors.joined(separator: " "))，未知鄰居:\(hiddenNeighbors.joined(separator: " "))"
                        )
                    }
                }
            }
        }

        let frontierText = frontierList.joined(separator: "\n")
        let summaryText = """
        【棋盤規格】: \(rows)列 × \(cols)行，總地雷數: \(totalMines)，目前已插旗: \(flaggedCount)
        【Solver 數學解算概要】: \(solverResult.summary) (狀態: \(solverResult.status.rawValue))
        【邊界數字與約束條件】:
        \(frontierText.isEmpty ? "目前無活躍數字邊界" : frontierText)
        """
        return summaryText
    }

    // MARK: - 提取與清理 JSON 回應
    public func parseRawAIResponse(_ content: String) throws -> RawAIAnalysisResponse {
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 清理可能的 markdown 標籤 ```json ... ```
        if jsonString.hasPrefix("```") {
            let lines = jsonString.components(separatedBy: "\n")
            if lines.count >= 2 {
                let cleanedLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
                jsonString = cleanedLines.joined(separator: "\n")
            }
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw OllamaError.decodingFailed("無法將文字轉換為 UTF-8 格式")
        }

        do {
            return try JSONDecoder().decode(RawAIAnalysisResponse.self, from: data)
        } catch {
            throw OllamaError.decodingFailed("JSON 結構不符預期: \(error.localizedDescription)")
        }
    }

    // MARK: - 嚴格的 AI 安全防護檢驗
    public func validateAISuggestions(
        rawSuggestions: [RawAISuggestion],
        grid: [[PublicCell]],
        rows: Int,
        cols: Int,
        solverResult: SolverResult
    ) -> [ValidatedAISuggestion] {
        var validatedList: [ValidatedAISuggestion] = []

        for raw in rawSuggestions {
            let r = raw.row
            let c = raw.column
            let rawAction = raw.action.lowercased()
            let action: RecommendedAction = (rawAction == "flag") ? .flag : (rawAction == "guess" ? .guess : .reveal)
            let confidence = raw.confidence ?? 50

            // 1. 座標越界檢查
            guard r >= 0 && r < rows && c >= 0 && c < cols else {
                validatedList.append(ValidatedAISuggestion(
                    row: r,
                    column: c,
                    action: action,
                    aiReason: raw.reason,
                    aiConfidence: confidence,
                    trueMineProbability: nil,
                    verificationStatus: .rejected,
                    rejectionNote: "座標 (\(r),\(c)) 超出棋盤合法範圍 (0~\(rows-1), 0~\(cols-1))。"
                ))
                continue
            }

            // 2. 格子狀態合法性檢查 (不能建議已揭開或已插旗之格子)
            let targetCell = grid[r][c]
            guard targetCell.isHidden else {
                let stateName = targetCell.isFlagged ? "已插旗" : "已翻開"
                validatedList.append(ValidatedAISuggestion(
                    row: r,
                    column: c,
                    action: action,
                    aiReason: raw.reason,
                    aiConfidence: confidence,
                    trueMineProbability: nil,
                    verificationStatus: .rejected,
                    rejectionNote: "該格為「\(stateName)」狀態，不可作為下一步操作建議。"
                ))
                continue
            }

            // 3. 交叉比對 Solver 數學客觀機率真值
            let key = "\(r),\(c)"
            let solverProb = solverResult.probabilities[key]?.mineProbability

            let verificationStatus: AIVerificationStatus
            if let p = solverProb {
                if abs(p) < 1e-6 {
                    verificationStatus = .verifiedSafe
                } else if abs(p - 1.0) < 1e-6 {
                    verificationStatus = .verifiedMine
                } else {
                    verificationStatus = .speculation
                }
            } else {
                verificationStatus = .speculation
            }

            validatedList.append(ValidatedAISuggestion(
                row: r,
                column: c,
                action: action,
                aiReason: raw.reason,
                aiConfidence: confidence,
                trueMineProbability: solverProb,
                verificationStatus: verificationStatus,
                rejectionNote: nil
            ))
        }

        return validatedList
    }
}
