import Foundation

/// 遊戲內部單一格子的完整實體資料
public struct Cell: Identifiable, Equatable, Sendable, Codable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int

    /// 當前互動狀態
    public var state: CellState

    /// 是否埋有地雷 (內部掌控，不直接對外部 Solver/AI 暴露)
    public var hasMine: Bool

    /// 相鄰 8 格之地雷總數 (0~8)
    public var neighboringMines: Int

    public init(
        row: Int,
        column: Int,
        state: CellState = .hidden,
        hasMine: Bool = false,
        neighboringMines: Int = 0
    ) {
        self.row = row
        self.column = column
        self.state = state
        self.hasMine = hasMine
        self.neighboringMines = neighboringMines
    }

    // MARK: - 快捷狀態判定

    public var isRevealed: Bool {
        state == .revealed
    }

    public var isFlagged: Bool {
        state == .flagged
    }

    public var isHidden: Bool {
        state == .hidden
    }

    public var isExploded: Bool {
        state == .exploded
    }
}
