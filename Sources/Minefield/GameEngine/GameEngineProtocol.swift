import Foundation

/// 遊戲進行狀態
public enum GameState: String, Codable, Sendable, Equatable {
    /// 準備就緒 (尚未點擊第一步，地雷尚未部署)
    case ready
    /// 進行中 (計時器運行中)
    case inProgress
    /// 勝利 (所有非地雷格子已成功翻開)
    case won
    /// 失敗 (經典模式下踩中地雷)
    case lost
}

/// 掃雷遊戲引擎介面協定
public protocol GameEngineProtocol: AnyObject {
    // MARK: - 唯讀狀態
    var difficulty: GameDifficulty { get }
    var mode: GameMode { get }
    var state: GameState { get }
    var currentSeed: UInt64 { get }

    /// 剩餘旗幟計數 (總地雷數 - 目前已插旗數)
    var remainingMinesToFlag: Int { get }

    /// 踩爆地雷次數 (懲罰模式專用)
    var explodedMineCount: Int { get }

    /// 單顆踩雷懲罰時間 (秒，預設 30.0)
    var penaltySecondsPerMine: TimeInterval { get set }

    /// 純遊玩經過時間 (秒)
    var pureElapsedTime: TimeInterval { get }

    /// 加總懲罰後的總成績時間 (秒)
    var totalTimeWithPenalties: TimeInterval { get }

    /// 棋盤內部結構 (僅供引擎與除錯測試使用)
    var internalBoard: Board { get }

    // MARK: - 安全公開視圖 (供 UI、AI、Solver 讀取)
    func publicBoard() -> [[PublicCell]]
    func publicCell(atRow row: Int, column: Int) -> PublicCell?

    // MARK: - 操作指令
    /// 翻開指定格子 (左鍵點擊)
    @discardableResult
    func revealCell(atRow row: Int, column: Int) -> Bool

    /// 插旗或取消插旗 (右鍵點擊或長按操作)
    @discardableResult
    func toggleFlag(atRow row: Int, column: Int) -> Bool

    /// 快捷翻開周圍未插旗格子 (Chording: 點擊已翻開的數字格)
    @discardableResult
    func chordReveal(atRow row: Int, column: Int) -> Bool

    // MARK: - 重設與新局
    /// 重新開始當前棋盤 (保留相同 Seed 與地雷分布)
    func restartCurrentGame()

    /// 以指定難度開始隨機新局
    func startNewGame(difficulty: GameDifficulty, mode: GameMode, seed: UInt64?)

    /// 以自訂難度開始新局
    func startCustomGame(config: CustomBoardConfig, mode: GameMode, seed: UInt64?)
}
