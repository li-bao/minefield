import Foundation
import Combine

/// 自動排雷執行狀態
public enum AutoPlayState: Equatable {
    case idle
    case running
    case paused
    case pausedOnGuess(lowestRiskCandidate: RiskCandidate?)
    case finishedWon
    case finishedLost
}

/// 自動排雷速度選項
public enum AutoPlaySpeed: Double, CaseIterable, Identifiable {
    case fastest = 0.2
    case fast = 0.5
    case normal = 1.0
    case slow = 2.0
    case slowest = 5.0

    public var id: Double { rawValue }

    public var title: String {
        switch self {
        case .fastest: return "極速 (0.2s)"
        case .fast: return "快速 (0.5s)"
        case .normal: return "標準 (1.0s)"
        case .slow: return "慢速 (2.0s)"
        case .slowest: return "深思 (5.0s)"
        }
    }
}

/// 自動遊玩與智慧排雷引擎 (AutoPlayEngine)
@MainActor
public final class AutoPlayEngine: ObservableObject {
    public static let shared = AutoPlayEngine()

    @Published public private(set) var state: AutoPlayState = .idle
    @Published public var speed: AutoPlaySpeed = .fast
    @Published public private(set) var stepsExecuted: Int = 0

    private var timerSubscription: AnyCancellable?
    private weak var currentEngine: GameEngine?

    public init() {}

    /// 開始自動連續排雷
    public func start(engine: GameEngine) {
        self.currentEngine = engine
        self.state = .running
        self.stepsExecuted = 0
        scheduleTimer()
    }

    /// 執行單一步驟排雷 (Step-by-step)
    public func stepOnce(engine: GameEngine) {
        self.currentEngine = engine
        executeOneStep()
    }

    /// 暫停
    public func pause() {
        timerSubscription?.cancel()
        timerSubscription = nil
        if state == .running {
            state = .paused
        }
    }

    /// 繼續
    public func resume() {
        guard let engine = currentEngine, engine.state == .inProgress || engine.state == .ready else {
            return
        }
        self.state = .running
        scheduleTimer()
    }

    /// 立即停止
    public func stop() {
        timerSubscription?.cancel()
        timerSubscription = nil
        self.state = .idle
    }

    /// 在猜測死局時執行 AI 救援並繼續自動排雷
    public func rescueAndContinue() {
        guard let engine = currentEngine else { return }
        let rescued = engine.executeAIRescue()
        if rescued != nil {
            self.state = .running
            scheduleTimer()
        } else {
            stop()
        }
    }

    private func scheduleTimer() {
        timerSubscription?.cancel()
        guard state == .running else { return }

        timerSubscription = Timer.publish(every: speed.rawValue, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.executeOneStep()
            }
    }

    private func executeOneStep() {
        guard let engine = currentEngine else {
            stop()
            return
        }

        if engine.state == .won {
            state = .finishedWon
            timerSubscription?.cancel()
            return
        }
        if engine.state == .lost {
            state = .finishedLost
            timerSubscription?.cancel()
            return
        }

        // 執行一步求解器自動翻開/標記
        let result = engine.performAutoSolveStep()
        stepsExecuted += (result.revealed.count + result.flagged.count)

        if engine.state == .won {
            state = .finishedWon
            timerSubscription?.cancel()
            return
        }
        if engine.state == .lost {
            state = .finishedLost
            timerSubscription?.cancel()
            return
        }

        // 若遇到無必然安全步 (GUESS_REQUIRED) 且沒有任何動作被執行
        if result.isGuessRequired && result.revealed.isEmpty && result.flagged.isEmpty {
            timerSubscription?.cancel()
            let solverResult = SmartSolver.shared.analyze(
                grid: engine.publicBoard(),
                totalMines: engine.internalBoard.totalMines,
                flaggedCount: engine.internalBoard.flaggedCount
            )
            state = .pausedOnGuess(lowestRiskCandidate: solverResult.lowestRiskCells.first)
        }
    }
}
