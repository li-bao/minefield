import Foundation

/// 外部觀察用格子視圖 (專門提供給 UI、AI 與 Solver 使用)
/// 保證隱藏格子的地雷資訊不會外洩，避免演算法作弊
public struct PublicCell: Identifiable, Equatable, Sendable {
    public var id: String { "\(row),\(column)" }
    public let row: Int
    public let column: Int
    public let state: CellState

    /// 僅在已翻開 (revealed) 時提供相鄰地雷數字；未翻開時為 nil
    public let neighboringMines: Int?

    /// 是否為已踩爆的地雷格
    public var isExploded: Bool {
        state == .exploded
    }

    /// 是否已插旗
    public var isFlagged: Bool {
        state == .flagged
    }

    /// 是否已翻開 (安全或爆炸)
    public var isRevealed: Bool {
        state == .revealed || state == .exploded
    }

    /// 是否未揭開
    public var isHidden: Bool {
        state == .hidden
    }

    public init(row: Int, column: Int, state: CellState, neighboringMines: Int?) {
        self.row = row
        self.column = column
        self.state = state
        self.neighboringMines = neighboringMines
    }

    /// 從引擎內部 Cell 產生安全遮罩投影
    public static func from(cell: Cell, isGameOver: Bool = false) -> PublicCell {
        switch cell.state {
        case .revealed:
            return PublicCell(row: cell.row, column: cell.column, state: .revealed, neighboringMines: cell.neighboringMines)
        case .exploded:
            return PublicCell(row: cell.row, column: cell.column, state: .exploded, neighboringMines: nil)
        case .flagged:
            return PublicCell(row: cell.row, column: cell.column, state: .flagged, neighboringMines: nil)
        case .hidden:
            if isGameOver && cell.hasMine {
                // 遊戲結束時可透視未標記之地雷 (由引擎主動決定是否投影)
                return PublicCell(row: cell.row, column: cell.column, state: .hidden, neighboringMines: nil)
            }
            return PublicCell(row: cell.row, column: cell.column, state: .hidden, neighboringMines: nil)
        }
    }
}
