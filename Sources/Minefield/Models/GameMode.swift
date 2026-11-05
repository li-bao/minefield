import Foundation

/// 遊戲遊玩與棋盤模式 (包含 Phase 4.75 全面擴充之六大核心模式)
public enum GameMode: String, Codable, Sendable, CaseIterable, Equatable, Identifiable {
    /// A. 經典模式 (Classic Mode)：地雷位置自開局固定，絕不允許動態修改，保留最純粹之經典掃雷
    case classic = "經典模式"

    /// B. 無猜認證模式 (No-Guess Mode)：開局驗證存在純邏輯解題路徑，具備可追溯種子與認證標章
    case noGuess = "無猜認證模式"

    /// C. AI 輔助模式 (AI Assisted Mode)：啟用 Ollama 本地 AI 局勢分析與教練推理解釋，玩家手動確認套用
    case aiAssisted = "AI 輔助模式"

    /// D. AI 救援模式 (AI Rescue Mode)：當遇猜測死局時，由遊戲引擎安全揭露真實安全格，明確標記救援
    case aiRescue = "AI 救援模式"

    /// E. 沙盒實驗室 (Sandbox Mode)：完全自訂尺寸、地雷與測試 Solver，不計入正式戰績
    case sandbox = "沙盒實驗室"

    /// F. AI 自動遊玩模式 (AI Auto Play Mode)：由求解器自動推進排雷，遇猜測暫停或呼叫救援
    case aiAutoPlay = "AI 自動遊玩模式"

    /// 相容保留：懲罰模式 (Penalty Mode)
    case penalty = "懲罰模式"

    /// 相容保留別名
    public static var aiExpert: GameMode { .aiAssisted }

    public var id: String { rawValue }

    public var isRepairAllowed: Bool {
        switch self {
        case .classic, .sandbox: return false
        case .noGuess, .aiAssisted, .aiRescue, .aiAutoPlay, .penalty: return true
        }
    }

    public var isAutoRepairEnabled: Bool {
        self == .noGuess
    }

    public var isAIEnabled: Bool {
        switch self {
        case .aiAssisted, .aiRescue, .aiAutoPlay: return true
        default: return false
        }
    }

    public var isRanked: Bool {
        self != .sandbox
    }
}
