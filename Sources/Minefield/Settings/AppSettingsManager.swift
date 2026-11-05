import SwiftUI

public enum AppearanceSetting: String, CaseIterable, Identifiable, Sendable {
    case system = "跟隨系統"
    case dark = "深色模式"
    case light = "淺色模式"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// 應用程式偏好設定管理器 (支援 UserDefaults 持久化)
public final class AppSettingsManager: ObservableObject {
    public static let shared = AppSettingsManager()

    @AppStorage("appearanceMode") public var appearanceMode: String = AppearanceSetting.system.rawValue
    @AppStorage("soundEnabled") public var soundEnabled: Bool = true
    @AppStorage("animationsEnabled") public var animationsEnabled: Bool = true
    @AppStorage("longPressDuration") public var longPressDuration: Double = 0.45
    @AppStorage("penaltySeconds") public var penaltySeconds: Double = 30.0
    @AppStorage("selectedGameMode") public var selectedGameMode: String = GameMode.penalty.rawValue
    @AppStorage("ollamaHost") public var ollamaHost: String = "http://localhost:11434"
    @AppStorage("ollamaModel") public var ollamaModel: String = "llama3:latest"

    public var currentAppearance: AppearanceSetting {
        get { AppearanceSetting(rawValue: appearanceMode) ?? .system }
        set { appearanceMode = newValue.rawValue }
    }

    public var currentGameMode: GameMode {
        get { GameMode(rawValue: selectedGameMode) ?? .penalty }
        set { selectedGameMode = newValue.rawValue }
    }

    public init() {}

    /// 重設為預設值
    public func resetToDefaults() {
        appearanceMode = AppearanceSetting.system.rawValue
        soundEnabled = true
        animationsEnabled = true
        longPressDuration = 0.45
        penaltySeconds = 30.0
        selectedGameMode = GameMode.penalty.rawValue
        ollamaHost = "http://localhost:11434"
        ollamaModel = "llama3:latest"
    }
}
