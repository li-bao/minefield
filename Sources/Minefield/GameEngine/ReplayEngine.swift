import Foundation
import Combine

/// 棋局回放控制器 (Replay Engine)
public final class ReplayEngine: ObservableObject {
    public static let shared = ReplayEngine()

    // MARK: - 錄製狀態
    private var isRecording = false
    private var recordedSteps: [ReplayStep] = []
    private var initialBoardSnapshot: Board?
    private var recordingSeed: UInt64 = 0
    private var recordingDifficulty: GameDifficulty = .intermediate
    private var recordingMode: GameMode = .penalty
    private var recordingStartTime: Date?

    // MARK: - 回放狀態
    @Published public private(set) var activeRecord: ReplayGameRecord?
    @Published public private(set) var currentStepIndex: Int = 0
    @Published public private(set) var isPlaying: Bool = false
    @Published public var playbackSpeed: Double = 1.0 // 0.5x, 1x, 2x, 4x

    private var playbackTimer: AnyCancellable?

    public init() {}

    // MARK: - 錄製控制

    public func startRecording(
        initialBoard: Board,
        difficulty: GameDifficulty,
        mode: GameMode,
        seed: UInt64
    ) {
        self.isRecording = true
        self.recordedSteps = []
        self.initialBoardSnapshot = initialBoard
        self.recordingDifficulty = difficulty
        self.recordingMode = mode
        self.recordingSeed = seed
        self.recordingStartTime = Date()

        // 記錄初始遊戲開始步驟
        recordStep(
            actionType: .gameStart,
            coordinate: nil,
            description: "棋局初始化，種子: \(seed)",
            board: initialBoard,
            state: .ready,
            explodedCount: 0
        )
    }

    public func recordStep(
        actionType: ReplayActionType,
        coordinate: GridCoordinate?,
        description: String,
        board: Board,
        state: GameState,
        explodedCount: Int
    ) {
        guard isRecording else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(recordingStartTime ?? now)
        let step = ReplayStep(
            stepIndex: recordedSteps.count,
            timestamp: elapsed,
            actionType: actionType,
            coordinate: coordinate,
            description: description,
            boardSnapshot: board,
            stateSnapshot: state,
            explodedCount: explodedCount
        )
        recordedSteps.append(step)
    }

    public func finishRecording(
        finalState: GameState,
        totalTime: TimeInterval,
        fairnessRecord: GameFairnessRecord
    ) -> ReplayGameRecord? {
        guard isRecording, let initial = initialBoardSnapshot else { return nil }
        isRecording = false

        let record = ReplayGameRecord(
            difficulty: recordingDifficulty,
            mode: recordingMode,
            seed: recordingSeed,
            totalTime: totalTime,
            finalState: finalState,
            initialBoard: initial,
            steps: recordedSteps,
            fairnessRecord: fairnessRecord
        )
        return record
    }

    // MARK: - 回放控制

    public func loadRecord(_ record: ReplayGameRecord) {
        pause()
        self.activeRecord = record
        self.currentStepIndex = 0
    }

    public var currentStep: ReplayStep? {
        guard let record = activeRecord,
              currentStepIndex >= 0 && currentStepIndex < record.steps.count else {
            return nil
        }
        return record.steps[currentStepIndex]
    }

    public var currentBoard: Board? {
        currentStep?.boardSnapshot ?? activeRecord?.initialBoard
    }

    public var totalSteps: Int {
        activeRecord?.steps.count ?? 0
    }

    public func play() {
        guard let record = activeRecord, !record.steps.isEmpty else { return }
        isPlaying = true
        scheduleNextPlaybackTick()
    }

    public func pause() {
        isPlaying = false
        playbackTimer?.cancel()
        playbackTimer = nil
    }

    public func stepForward() {
        guard let record = activeRecord else { return }
        if currentStepIndex < record.steps.count - 1 {
            currentStepIndex += 1
        } else {
            pause()
        }
    }

    public func stepBackward() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }

    public func seek(toStep index: Int) {
        guard let record = activeRecord else { return }
        currentStepIndex = max(0, min(index, record.steps.count - 1))
    }

    private func scheduleNextPlaybackTick() {
        playbackTimer?.cancel()
        guard isPlaying else { return }

        let interval = max(0.1, 1.0 / playbackSpeed)
        playbackTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.currentStepIndex < (self.activeRecord?.steps.count ?? 0) - 1 {
                    self.currentStepIndex += 1
                } else {
                    self.pause()
                }
            }
    }
}
