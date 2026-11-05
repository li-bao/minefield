import SwiftUI

/// 遊戲偏好設定視窗 (完整整合主題、外觀、無障礙、音效、AI 配置與快捷鍵)
public struct SettingsSheet: View {
    @ObservedObject public var settings: AppSettingsManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(settings: AppSettingsManager = .shared) {
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                Text("偏好設定與系統配置")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.mintAccent)
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 主題與視覺風格
                    settingsSection(title: "🎨 視覺主題與網格尺寸") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("風格主題", selection: $themeManager.activeThemeId) {
                                ForEach(Array(ThemeManager.presetThemes.values), id: \.id) { t in
                                    Text(t.name).tag(t.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: themeManager.activeThemeId) {
                                themeManager.setTheme(byId: themeManager.activeThemeId)
                            }

                            Picker("棋盤格子尺寸", selection: $themeManager.activeScaleRaw) {
                                ForEach(BoardScaleTier.allCases) { scale in
                                    Text(scale.rawValue).tag(scale.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            Toggle("高對比 / 色盲友善色彩", isOn: $themeManager.colorblindMode)
                        }
                    }

                    // 遊戲規則與模式
                    settingsSection(title: "⚔️ 遊戲規則與模式") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("核心遊戲模式", selection: $settings.selectedGameMode) {
                                ForEach(GameMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.menu)

                            Text(modeDescription(settings.currentGameMode))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(6)

                            if settings.currentGameMode == .penalty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("單顆踩雷懲罰秒數")
                                            .font(.system(size: 13))
                                        Spacer()
                                        Text("\(Int(settings.penaltySeconds)) 秒")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(ColorTheme.mintAccent)
                                    }
                                    Slider(value: $settings.penaltySeconds, in: 10...60, step: 5)
                                        .tint(ColorTheme.mintAccent)
                                }
                            }
                        }
                    }

                    // 手勢與操作設定
                    settingsSection(title: "🖱️ 手勢與長按判定") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("長按插旗觸發時間")
                                    .font(.system(size: 13))
                                Spacer()
                                Text(String(format: "%.2f 秒", settings.longPressDuration))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ColorTheme.mintAccent)
                            }
                            Slider(value: $settings.longPressDuration, in: 0.30...0.80, step: 0.05)
                                .tint(ColorTheme.mintAccent)
                            Text("滑鼠左鍵按住超過此時間將直接插旗，避免與短按翻開衝突。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 視聽反饋
                    settingsSection(title: "🔊 視聽音效與動畫") {
                        Toggle("啟用遊戲原生音效", isOn: $settings.soundEnabled)
                        Toggle("啟用平滑過渡動畫", isOn: $settings.animationsEnabled)
                    }

                    // 本地 AI (Ollama) 配置
                    settingsSection(title: "🤖 本機 Ollama AI 配置") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("端點")
                                    .frame(width: 50, alignment: .leading)
                                TextField("http://localhost:11434", text: $settings.ollamaHost)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Text("模型")
                                    .frame(width: 50, alignment: .leading)
                                TextField("llama3:latest", text: $settings.ollamaModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    // 快捷鍵說明
                    settingsSection(title: "⌨️ 鍵盤無障礙操作指引") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Space: 翻開選中格 ｜ F: 插旗 / 取消插旗")
                            Text("• H: 索取提示 ｜ S: 智慧分析 ｜ A: AI 專家問答")
                            Text("• U: 復原 (Undo) ｜ Shift+U: 重做 (Redo)")
                            Text("• Cmd+R: 重新開局 ｜ Cmd+1/2/3: 切換難度")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }

                    // 重設按鈕
                    Button(role: .destructive) {
                        settings.resetToDefaults()
                    } label: {
                        Text("重設所有設定為預設值")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 620)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private func modeDescription(_ mode: GameMode) -> String {
        switch mode {
        case .classic:
            return "【經典模式】：地雷位置從開局固定，不允許系統或 AI 修改棋盤，保留最純粹之經典掃雷競技體驗。"
        case .noGuess:
            return "【無猜認證模式】：開局經全路徑模擬保證 100% 邏輯可解。若遭遇死局自動動態微調未揭開隱藏雷。"
        case .aiAssisted:
            return "【AI 輔助模式】：啟用本地 Ollama AI 專家解盤、推理解析與修復建議預覽（需玩家確認）。"
        case .aiRescue:
            return "【AI 救援模式】：遭遇死局時由遊戲引擎安全揭露真實安全格，並留下客觀救援紀錄。"
        case .sandbox:
            return "【沙盒實驗室】：完全自訂地雷與棋盤，測試各種 Solver 情境，不計入正式競速戰績。"
        case .aiAutoPlay:
            return "【AI 自動遊玩】：求解器自動翻開安全格與標記地雷，遇猜測自動暫停或呼叫救援。"
        case .penalty:
            return "【懲罰模式】：踩中地雷不立即死局，每踩一顆累加懲罰秒數，適合休閒體驗。"
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTheme.cardBackground(for: colorScheme))
            .cornerRadius(10)
        }
    }
}
