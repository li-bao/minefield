import Foundation

/// 掃雷內部棋盤資料實體
public struct Board: Equatable, Sendable, Codable {
    public let rows: Int
    public let columns: Int
    public let totalMines: Int
    public var grid: [[Cell]]

    public init(rows: Int, columns: Int, totalMines: Int) {
        self.rows = rows
        self.columns = columns
        self.totalMines = totalMines
        self.grid = (0..<rows).map { r in
            (0..<columns).map { c in
                Cell(row: r, column: c)
            }
        }
    }

    public subscript(row: Int, column: Int) -> Cell {
        get { grid[row][column] }
        set { grid[row][column] = newValue }
    }

    /// 檢查座標是否在棋盤合法邊界內
    public func isValidCoordinate(row: Int, column: Int) -> Bool {
        row >= 0 && row < rows && column >= 0 && column < columns
    }

    /// 取得指定格子的相鄰 8 方位有效座標列表
    public func neighborCoordinates(ofRow row: Int, column: Int) -> [(row: Int, column: Int)] {
        var neighbors: [(row: Int, column: Int)] = []
        neighbors.reserveCapacity(8)
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = column + dc
                if isValidCoordinate(row: nr, column: nc) {
                    neighbors.append((row: nr, column: nc))
                }
            }
        }
        return neighbors
    }

    /// 統計相鄰格子中已被插旗的數量
    public func flaggedNeighborsCount(ofRow row: Int, column: Int) -> Int {
        neighborCoordinates(ofRow: row, column: column).reduce(0) { count, coord in
            grid[coord.row][coord.column].isFlagged ? count + 1 : count
        }
    }

    /// 棋盤非地雷的安全格子總數
    public var totalSafeCells: Int {
        (rows * columns) - totalMines
    }

    /// 目前已安全翻開的格子數
    public var revealedCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if grid[r][c].isRevealed { count += 1 }
            }
        }
        return count
    }

    /// 目前已插旗的格子數
    public var flaggedCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if grid[r][c].isFlagged { count += 1 }
            }
        }
        return count
    }

    /// 目前已踩爆的地雷數
    public var explodedCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if grid[r][c].isExploded { count += 1 }
            }
        }
        return count
    }

    /// 產生對外安全投影視圖 (AI, Solver 與 UI 讀取用)
    public func toPublicGrid(isGameOver: Bool = false) -> [[PublicCell]] {
        grid.map { row in
            row.map { cell in
                PublicCell.from(cell: cell, isGameOver: isGameOver)
            }
        }
    }
}
