import Foundation

/// 使用者遊戲偏好設定
public struct GameSettings: Equatable, Sendable {
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    public var questionMarksEnabled: Bool
    public var defaultDifficulty: GameDifficulty
    public var defaultMode: GameMode
    public var penaltySecondsPerMine: TimeInterval

    public init(
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        questionMarksEnabled: Bool = false,
        defaultDifficulty: GameDifficulty = .intermediate,
        defaultMode: GameMode = .penalty,
        penaltySecondsPerMine: TimeInterval = 30.0
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.questionMarksEnabled = questionMarksEnabled
        self.defaultDifficulty = defaultDifficulty
        self.defaultMode = defaultMode
        self.penaltySecondsPerMine = penaltySecondsPerMine
    }
}
