import SwiftUI

/// AI 專家分析結果面板
public struct AIAnalysisSheet: View {
    public let analysis: ValidatedAIAnalysis?
    public let isLoading: Bool
    public let errorMessage: String?
    public let onApplySuggestion: (ValidatedAISuggestion) -> Void
    public let onRetry: () -> Void
    public let onOpenOllamaSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(
        analysis: ValidatedAIAnalysis?,
        isLoading: Bool,
        errorMessage: String?,
        onApplySuggestion: @escaping (ValidatedAISuggestion) -> Void,
        onRetry: @escaping () -> Void,
        onOpenOllamaSettings: @escaping () -> Void
    ) {
        self.analysis = analysis
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onApplySuggestion = onApplySuggestion
        self.onRetry = onRetry
        self.onOpenOllamaSettings = onOpenOllamaSettings
    }

    public var body: some View {
        VStack(spacing: 20) {
            // 頂部標題列
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTheme.indigoAccent)
                    Text("AI 專家局勢推演")
                        .font(.system(size: 20, weight: .bold))
                }

                if let model = analysis?.modelName {
                    Text(model)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }

                Spacer()

                Button("關閉") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
            }

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let data = analysis {
                contentView(data)
            } else {
                Text("尚無分析資料")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(26)
        .frame(width: 560, height: 600)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    // MARK: - 載入中視圖
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(ColorTheme.indigoAccent)

            Text("正在向本地 Ollama 專家模型進行推演...")
                .font(.system(size: 15, weight: .semibold))

            Text("已先行完成 CSP 數學約束求解，正在整合自然語言深度解盤。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 錯誤視圖
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(ColorTheme.amberWarning)

            Text("AI 推論服務無法連線")
                .font(.system(size: 17, weight: .bold))

            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 14) {
                Button("重新嘗試") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.mintAccent)
                .foregroundStyle(.black)

                Button("調整 Ollama 設定") {
                    dismiss()
                    onOpenOllamaSettings()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    // MARK: - 正式分析內容
    @ViewBuilder
    private func contentView(_ data: ValidatedAIAnalysis) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // 綜合總結卡片
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("專家局勢綜合研判", systemImage: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ColorTheme.indigoAccent)
                        Spacer()
                        Text("CSP 狀態: \(data.solverStatus.rawValue)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ColorTheme.mintAccent)
                    }

                    Text(data.summary)
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTheme.cardBackground(for: colorScheme))
                )

                // 建議操作列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("具體步驟建議與安全驗證")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)

                    if data.suggestions.isEmpty {
                        Text("AI 本輪未提出具體步驟，建議參考內建「智慧排雷」。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(data.suggestions) { item in
                            suggestionCard(item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func suggestionCard(_ item: ValidatedAISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題與驗證標章
            HStack {
                HStack(spacing: 8) {
                    Text("目標格: (\(item.row), \(item.column))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))

                    actionBadge(item.action)
                }

                Spacer()

                verificationBadge(item.verificationStatus)
            }

            // 真實機率與 AI 信賴度
            HStack(spacing: 14) {
                if let prob = item.trueMineProbability {
                    Text("客觀地雷機率: \(String(format: "%.1f%%", prob * 100))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(prob == 0.0 ? ColorTheme.mintAccent : (prob == 1.0 ? ColorTheme.amberWarning : .secondary))
                }

                Text("模型宣稱信心: \(item.aiConfidence)%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // AI 推理說明
            Text(item.aiReason)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // 若被安全防護層拒絕之說明
            if let note = item.rejectionNote {
                HStack(spacing: 6) {
                    Image(systemName: "shield.slash.fill")
                    Text(note)
                }
                .font(.system(size: 11))
                .foregroundStyle(ColorTheme.crimsonExplosion)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(ColorTheme.crimsonExplosion.opacity(0.1)))
            }

            // 採納按鈕 (被拒絕者不可採納)
            if item.verificationStatus != .rejected {
                HStack {
                    Spacer()
                    Button("採納此建議") {
                        onApplySuggestion(item)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(item.verificationStatus == .verifiedSafe ? ColorTheme.mintAccent : (item.verificationStatus == .verifiedMine ? ColorTheme.amberWarning : ColorTheme.indigoAccent))
                    .foregroundStyle(item.verificationStatus == .verifiedSafe ? .black : .white)
                    .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(item.verificationStatus == .rejected ? ColorTheme.crimsonExplosion.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func actionBadge(_ action: RecommendedAction) -> some View {
        Text(action.rawValue)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(action == .reveal ? ColorTheme.mintAccent.opacity(0.2) : (action == .flag ? ColorTheme.amberWarning.opacity(0.2) : Color.primary.opacity(0.1)))
            )
            .foregroundStyle(action == .reveal ? ColorTheme.mintAccent : (action == .flag ? ColorTheme.amberWarning : .primary))
    }

    @ViewBuilder
    private func verificationBadge(_ status: AIVerificationStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status == .verifiedSafe || status == .verifiedMine ? "checkmark.shield.fill" : (status == .speculation ? "questionmark.circle.fill" : "xmark.shield.fill"))
            Text(status.rawValue)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor(status).opacity(0.14))
        )
        .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: AIVerificationStatus) -> Color {
        switch status {
        case .verifiedSafe: return ColorTheme.mintAccent
        case .verifiedMine: return ColorTheme.amberWarning
        case .speculation: return Color(red: 0.96, green: 0.62, blue: 0.15)
        case .rejected: return ColorTheme.crimsonExplosion
        }
    }
}
