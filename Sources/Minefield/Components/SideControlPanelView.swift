import SwiftUI

/// 遊戲底部輔助控制面板 (包含 Undo/Redo、提示、AI教練、熱力圖、What-if、自動排雷、AI問答、歷程回放)
public struct SideControlPanelView: View {
    @ObservedObject public var engine: GameEngine
    public let isSolverActive: Bool
    public let canRepair: Bool
    public let onToggleSmartSolver: () -> Void
    public let onHintRequested: () -> Void
    public let onAutoSolveRequested: () -> Void
    public let onAIExpertRequested: () -> Void
    public let onReasoningHistoryRequested: () -> Void
    public let onRepairRequested: () -> Void
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onOpenHeatmap: () -> Void
    public let onOpenCoach: () -> Void
    public let onOpenWhatIf: () -> Void
    public let onOpenAIChat: () -> Void
    public let onOpenReplay: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var undoManager = UndoRedoManager.shared

    public init(
        engine: GameEngine,
        isSolverActive: Bool,
        canRepair: Bool = false,
        onToggleSmartSolver: @escaping () -> Void,
        onHintRequested: @escaping () -> Void,
        onAutoSolveRequested: @escaping () -> Void,
        onAIExpertRequested: @escaping () -> Void,
        onReasoningHistoryRequested: @escaping () -> Void,
        onRepairRequested: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onOpenHeatmap: @escaping () -> Void,
        onOpenCoach: @escaping () -> Void,
        onOpenWhatIf: @escaping () -> Void,
        onOpenAIChat: @escaping () -> Void,
        onOpenReplay: @escaping () -> Void
    ) {
        self.engine = engine
        self.isSolverActive = isSolverActive
        self.canRepair = canRepair
        self.onToggleSmartSolver = onToggleSmartSolver
        self.onHintRequested = onHintRequested
        self.onAutoSolveRequested = onAutoSolveRequested
        self.onAIExpertRequested = onAIExpertRequested
        self.onReasoningHistoryRequested = onReasoningHistoryRequested
        self.onRepairRequested = onRepairRequested
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onOpenHeatmap = onOpenHeatmap
        self.onOpenCoach = onOpenCoach
        self.onOpenWhatIf = onOpenWhatIf
        self.onOpenAIChat = onOpenAIChat
        self.onOpenReplay = onOpenReplay
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 左側：模式、難度評級、Undo/Redo
            HStack(spacing: 8) {
                // 復原 / 重做
                HStack(spacing: 2) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!undoManager.canUndo)
                    .padding(6)
                    .background(Color.primary.opacity(undoManager.canUndo ? 0.08 : 0.03))
                    .cornerRadius(6)
                    .help("復原上一步 (Undo, 快速鍵: U)")

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!undoManager.canRedo)
                    .padding(6)
                    .background(Color.primary.opacity(undoManager.canRedo ? 0.08 : 0.03))
                    .cornerRadius(6)
                    .help("重做下一步 (Redo, 快速鍵: Shift+U)")
                }

                Divider().frame(height: 20)

                // 模式標籤
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(engine.mode.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ColorTheme.indigoAccent)
                        if engine.fairnessRecord.isPureClassicValid {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTheme.mintAccent)
                                .help("純經典有效紀錄 (未經 AI 或修復)")
                        }
                    }
                }
            }

            Spacer()

            // 右側：核心功能按鈕群組
            HStack(spacing: 6) {
                // 1. 智慧排雷開關
                Button(action: onToggleSmartSolver) {
                    HStack(spacing: 3) {
                        Image(systemName: isSolverActive ? "brain.head.profile.fill" : "brain.head.profile")
                        Text(isSolverActive ? "隱藏" : "排雷")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSolverActive ? ColorTheme.mintAccent : Color.primary.opacity(0.08))
                .foregroundStyle(isSolverActive ? .black : .primary)
                .cornerRadius(6)
                .help("使用內建 CSP 求解器計算機率 (快速鍵: S)")

                // 2. 提示按鈕
                Button(action: onHintRequested) {
                    Label("提示", systemImage: "lightbulb.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(ColorTheme.amberWarning.opacity(0.18))
                .foregroundStyle(ColorTheme.amberWarning)
                .cornerRadius(6)
                .help("多層次遞進提示 (快速鍵: H)")

                // 3. AI 教練
                Button(action: onOpenCoach) {
                    Label("教練", systemImage: "graduationcap.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(Color.purple)
                .cornerRadius(6)
                .help("AI 智慧解題教練：分級推導教學與數學原理解釋")

                // 4. 風險熱力圖
                Button(action: onOpenHeatmap) {
                    Label("熱力圖", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(Color.orange)
                .cornerRadius(6)
                .help("全盤機率分佈、資訊熵價值度量與色盲友善熱力圖")

                // 5. What-if 假設實驗室
                Button(action: onOpenWhatIf) {
                    Label("What-if", systemImage: "flask.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(Color.blue)
                .cornerRadius(6)
                .help("假設分析：測試某格若為雷或安全格之連鎖推導")

                // 6. 自動遊玩 (Auto Play)
                Button(action: onAutoSolveRequested) {
                    Label("自動", systemImage: "play.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(ColorTheme.mintAccent.opacity(0.15))
                .foregroundStyle(ColorTheme.mintAccent)
                .cornerRadius(6)
                .help("自動排雷與連續遊玩控制面板")

                // 7. AI 問答室
                Button(action: onOpenAIChat) {
                    Label("AI問答", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(ColorTheme.indigoAccent.opacity(0.2))
                .foregroundStyle(ColorTheme.indigoAccent)
                .cornerRadius(6)
                .help("與 AI 專家進行盤面互動問答 (快速鍵: A)")

                // 8. 棋局回放
                Button(action: onOpenReplay) {
                    Image(systemName: "film")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
                .help("查看本局完整操作時間軸與歷史回放")

                // 9. 推理歷程
                Button(action: onReasoningHistoryRequested) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
                .help("查看演算法推導歷史紀錄")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorTheme.elevatedCardBackground(for: colorScheme).opacity(0.9))
        .overlay(Divider(), alignment: .top)
    }
}
