import Foundation

/// 自訂棋盤驗證錯誤項目
public enum CustomBoardValidationError: LocalizedError, Equatable, Sendable {
    case widthOutOfRange(current: Int, min: Int, max: Int)
    case heightOutOfRange(current: Int, min: Int, max: Int)
    case minesOutOfRange(current: Int, min: Int, max: Int)

    public var errorDescription: String? {
        switch self {
        case let .widthOutOfRange(current, min, max):
            return "棋盤寬度 (\(current)) 超出合法範圍，必須介於 \(min) 至 \(max) 之間。"
        case let .heightOutOfRange(current, min, max):
            return "棋盤高度 (\(current)) 超出合法範圍，必須介於 \(min) 至 \(max) 之間。"
        case let .minesOutOfRange(current, min, max):
            return "地雷數量 (\(current)) 超出合法範圍，必須介於 \(min) 至 \(max) 顆之間 (需保留首發 3×3 安全區)。"
        }
    }
}

/// 自訂難度參數與即時驗證規則
public struct CustomBoardConfig: Equatable, Sendable, Codable {
    public static let minWidth = 5
    public static let maxWidth = 40
    public static let minHeight = 5
    public static let maxHeight = 30
    public static let minMines = 1

    public var width: Int
    public var height: Int
    public var mines: Int

    /// 計算給定長寬下的最大安全合法地雷數 (保證首發 3×3 = 9 格無雷)
    public static func maxMines(forWidth width: Int, height: Int) -> Int {
        let totalCells = width * height
        return max(1, totalCells - 9)
    }

    public init(width: Int = 10, height: Int = 10, mines: Int = 15) {
        self.width = width
        self.height = height
        self.mines = mines
    }

    /// 即時驗證目前長寬雷數是否完全合法
    public func validate() -> Result<CustomBoardConfig, CustomBoardValidationError> {
        Self.validate(width: width, height: height, mines: mines)
    }

    /// 靜態驗證函式
    public static func validate(width: Int, height: Int, mines: Int) -> Result<CustomBoardConfig, CustomBoardValidationError> {
        if width < minWidth || width > maxWidth {
            return .failure(.widthOutOfRange(current: width, min: minWidth, max: maxWidth))
        }
        if height < minHeight || height > maxHeight {
            return .failure(.heightOutOfRange(current: height, min: minHeight, max: maxHeight))
        }
        let maxAllowed = maxMines(forWidth: width, height: height)
        if mines < minMines || mines > maxAllowed {
            return .failure(.minesOutOfRange(current: mines, min: minMines, max: maxAllowed))
        }
        return .success(CustomBoardConfig(width: width, height: height, mines: mines))
    }
}
