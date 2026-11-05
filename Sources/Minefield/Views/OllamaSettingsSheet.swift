import SwiftUI

/// 獨立 Ollama 本機 AI 設定視窗
public struct OllamaSettingsSheet: View {
    @ObservedObject public var settings: AppSettingsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isTestingConnection = false
    @State private var connectionResultText: String?
    @State private var connectionSuccess: Bool?
    @State private var installedModels: [OllamaTagModel] = []
    @State private var timeoutSeconds: Double = 25.0

    public init(settings: AppSettingsManager = .shared) {
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: 22) {
            // 標題列
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTheme.indigoAccent)
                    Text("Ollama 本機 AI 設定")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.mintAccent)
                .foregroundStyle(.black)
            }

            ScrollView {
                VStack(spacing: 18) {
                    // 服務端點設定卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ollama 服務端點")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("http://localhost:11434", text: $settings.ollamaHost)
                                .textFieldStyle(.roundedBorder)

                            Button(action: runConnectionTest) {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("測試連線")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTestingConnection)
                        }

                        // 非本機隱私安全警語
                        if !OllamaService.isLocalEndpoint(settings.ollamaHost) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(ColorTheme.amberWarning)
                                Text("注意：非 localhost 端點可能產生對外網路流量。本機掃雷嚴格保護隱私，建議僅使用本機 Ollama 服務。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTheme.amberWarning)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(ColorTheme.amberWarning.opacity(0.12))
                            )
                        }

                        // 連線狀態反饋
                        if let result = connectionResultText {
                            HStack(spacing: 8) {
                                Image(systemName: (connectionSuccess == true) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle((connectionSuccess == true) ? ColorTheme.mintAccent : ColorTheme.crimsonExplosion)
                                Text(result)
                                    .font(.system(size: 12))
                                    .foregroundStyle((connectionSuccess == true) ? ColorTheme.mintAccent : ColorTheme.crimsonExplosion)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((connectionSuccess == true) ? ColorTheme.mintAccent.opacity(0.1) : ColorTheme.crimsonExplosion.opacity(0.1))
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTheme.cardBackground(for: colorScheme))
                    )

                    // 模型選擇卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("推論模型選擇")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)

                        if !installedModels.isEmpty {
                            Picker("已安裝模型", selection: $settings.ollamaModel) {
                                ForEach(installedModels) { m in
                                    Text("\(m.name) (\(m.humanReadableSize))").tag(m.name)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            HStack {
                                Text("模型名稱")
                                    .frame(width: 70, alignment: .leading)
                                TextField("llama3:latest", text: $settings.ollamaModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Text("※ 點擊上方「測試連線」可自動載入本地已安裝之模型清單。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // 逾時時間設定
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("最大推論等待時間")
                                    .font(.system(size: 13))
                                Spacer()
                                Text("\(Int(timeoutSeconds)) 秒")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ColorTheme.mintAccent)
                            }
                            Slider(value: $timeoutSeconds, in: 5...60, step: 5)
                                .tint(ColorTheme.mintAccent)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTheme.cardBackground(for: colorScheme))
                    )

                    // 說明規範
                    VStack(alignment: .leading, spacing: 6) {
                        Text("【隱私與安全政策】")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("• 棋盤資料絕不上傳任何雲端 AI API，僅與您本機執行的 Ollama 實例通訊。")
                        Text("• 本程式不會自動執行 'ollama pull' 下載模型，只使用您本地現有模型。")
                        Text("• 所有 AI 專家分析結果均由本機數學 CSP 引擎進行二次驗證，確保邏輯絕對客觀。")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
            }
        }
        .padding(26)
        .frame(width: 520, height: 580)
        .background(ColorTheme.windowBackground(for: colorScheme))
        .task {
            // 視窗開啟時自動快速偵測一次
            await checkInitialConnection()
        }
    }

    private func checkInitialConnection() async {
        let result = await OllamaService.shared.testConnection(host: settings.ollamaHost)
        if case let .success(models) = result {
            installedModels = models
            connectionSuccess = true
            connectionResultText = "已成功連線至本機 Ollama 服務 (偵測到 \(models.count) 個模型)"
            // 若當前設定的模型不在清單中且清單非空，預設選第一個
            if !models.isEmpty && !models.contains(where: { $0.name == settings.ollamaModel }) {
                settings.ollamaModel = models[0].name
            }
        }
    }

    private func runConnectionTest() {
        isTestingConnection = true
        connectionResultText = nil

        Task {
            let result = await OllamaService.shared.testConnection(host: settings.ollamaHost)
            await MainActor.run {
                isTestingConnection = false
                switch result {
                case .success(let models):
                    self.installedModels = models
                    self.connectionSuccess = true
                    self.connectionResultText = "連線成功！偵測到 \(models.count) 個已安裝模型。"
                    if !models.isEmpty && !models.contains(where: { $0.name == settings.ollamaModel }) {
                        settings.ollamaModel = models[0].name
                    }
                case .failure(let error):
                    self.connectionSuccess = false
                    self.connectionResultText = error.localizedDescription
                }
            }
        }
    }
}
