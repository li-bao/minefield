import Foundation

/// 遊戲難度等級設定
public enum GameDifficulty: Equatable, Sendable, Codable {
    case beginner
    case intermediate
    case expert
    case custom(CustomBoardConfig)

    private enum CodingKeys: String, CodingKey {
        case type, customConfig
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "beginner": self = .beginner
        case "intermediate": self = .intermediate
        case "expert": self = .expert
        case "custom":
            let config = try container.decode(CustomBoardConfig.self, forKey: .customConfig)
            self = .custom(config)
        default:
            self = .intermediate
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .beginner:
            try container.encode("beginner", forKey: .type)
        case .intermediate:
            try container.encode("intermediate", forKey: .type)
        case .expert:
            try container.encode("expert", forKey: .type)
        case .custom(let config):
            try container.encode("custom", forKey: .type)
            try container.encode(config, forKey: .customConfig)
        }
    }

    public var title: String {
        switch self {
        case .beginner:
            return "初級 (9×9, 10雷)"
        case .intermediate:
            return "中級 (16×16, 40雷)"
        case .expert:
            return "高級 (30×16, 99雷)"
        case .custom:
            return "自訂難度"
        }
    }

    /// 網格尺寸與地雷配置 (rows: 高度, columns: 寬度, mines: 地雷總數)
    public var configuration: (rows: Int, columns: Int, mines: Int) {
        switch self {
        case .beginner:
            return (rows: 9, columns: 9, mines: 10)
        case .intermediate:
            return (rows: 16, columns: 16, mines: 40)
        case .expert:
            return (rows: 16, columns: 30, mines: 99)
        case .custom(let config):
            return (rows: config.height, columns: config.width, mines: config.mines)
        }
    }
}
