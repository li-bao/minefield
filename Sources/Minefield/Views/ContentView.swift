import SwiftUI

public enum AppScreen: Equatable {
    case menu
    case playing
}

/// Minefield 主視圖容器 (Phase 4.75 全功能導航與彈窗協調)
public struct ContentView: View {
    @StateObject private var settings = AppSettingsManager.shared
    @StateObject private var engine = GameEngine(difficulty: .intermediate)

    @State private var currentScreen: AppScreen = .menu
    @State private var showingCustomSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingStatsSheet = false
    @State private var showingOllamaSheet = false
    @State private var showingDailyChallengeSheet = false
    @State private var showingSandboxSheet = false
    @State private var showingTutorialSheet = false
    @State private var showingAchievementsSheet = false

    public init() {}

    public var body: some View {
        ZStack {
            switch currentScreen {
            case .menu:
                MainMenuView(
                    onSelectDifficulty: { diff in
                        startWithDifficulty(diff)
                    },
                    onOpenCustomSheet: {
                        showingCustomSheet = true
                    },
                    onOpenDailyChallenge: {
                        showingDailyChallengeSheet = true
                    },
                    onOpenSandbox: {
                        showingSandboxSheet = true
                    },
                    onOpenTutorial: {
                        showingTutorialSheet = true
                    },
                    onOpenAchievements: {
                        showingAchievementsSheet = true
                    },
                    onOpenStats: {
                        showingStatsSheet = true
                    },
                    onOpenSettings: {
                        showingSettingsSheet = true
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .playing:
                GameView(
                    engine: engine,
                    longPressDuration: settings.longPressDuration,
                    onOpenSettings: {
                        showingSettingsSheet = true
                    },
                    onBackToMenu: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .menu
                        }
                    },
                    onOpenOllamaSettings: {
                        showingOllamaSheet = true
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .preferredColorScheme(settings.currentAppearance.colorScheme)
        .frame(minWidth: 880, minHeight: 640)
        .sheet(isPresented: $showingCustomSheet) {
            CustomBoardSheet { customConfig in
                startWithCustom(customConfig)
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsSheet(settings: settings)
        }
        .sheet(isPresented: $showingStatsSheet) {
            StatsSheet()
        }
        .sheet(isPresented: $showingOllamaSheet) {
            OllamaSettingsSheet(settings: settings)
        }
        .sheet(isPresented: $showingDailyChallengeSheet) {
            DailyChallengeSheet(
                onStartChallenge: { diff, seed in
                    engine.startNewGame(difficulty: diff, mode: .noGuess, seed: seed)
                    engine.penaltySecondsPerMine = settings.penaltySeconds
                    withAnimation { currentScreen = .playing }
                },
                onDismiss: { showingDailyChallengeSheet = false }
            )
        }
        .sheet(isPresented: $showingSandboxSheet) {
            SandboxLabSheet {
                showingSandboxSheet = false
            }
        }
        .sheet(isPresented: $showingTutorialSheet) {
            TutorialSheet {
                showingTutorialSheet = false
            }
        }
        .sheet(isPresented: $showingAchievementsSheet) {
            AchievementsSheet {
                showingAchievementsSheet = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restartGame)) { _ in
            if currentScreen == .playing {
                engine.restartCurrentGame()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startBeginner)) { _ in
            startWithDifficulty(.beginner)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startIntermediate)) { _ in
            startWithDifficulty(.intermediate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startExpert)) { _ in
            startWithDifficulty(.expert)
        }
    }

    private func startWithDifficulty(_ diff: GameDifficulty) {
        engine.startNewGame(
            difficulty: diff,
            mode: settings.currentGameMode
        )
        engine.penaltySecondsPerMine = settings.penaltySeconds
        withAnimation(.easeInOut(duration: 0.25)) {
            currentScreen = .playing
        }
    }

    private func startWithCustom(_ config: CustomBoardConfig) {
        engine.startCustomGame(
            config: config,
            mode: settings.currentGameMode
        )
        engine.penaltySecondsPerMine = settings.penaltySeconds
        withAnimation(.easeInOut(duration: 0.25)) {
            currentScreen = .playing
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
