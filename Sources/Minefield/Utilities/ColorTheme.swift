import SwiftUI

/// Minefield 高級感深色/淺色主題系統
public enum ColorTheme {
    // MARK: - 主強調色與輔色
    public static let mintAccent = Color(red: 0.18, green: 0.84, blue: 0.72)       // 淡青綠 #2DD4BF
    public static let indigoAccent = Color(red: 0.39, green: 0.40, blue: 0.95)     // 靛紫色 #6366F1
    public static let amberWarning = Color(red: 0.96, green: 0.62, blue: 0.15)     // 琥珀金 #F59E0B
    public static let crimsonExplosion = Color(red: 0.94, green: 0.27, blue: 0.24) // 爆炸紅 #EF4444

    // MARK: - 背景與卡片材質 (依深淺模式自適應)
    public static func windowBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.12) // 深石墨黑
            : Color(red: 0.96, green: 0.97, blue: 0.98) // 清透淺白灰
    }

    public static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.15, blue: 0.20).opacity(0.85) // 半透明深色卡片
            : Color.white.opacity(0.85)
    }

    public static func elevatedCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.17, green: 0.20, blue: 0.27)
            : Color.white
    }

    public static func gridBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.10) // 深沉背景底盤
            : Color(red: 0.88, green: 0.90, blue: 0.93)
    }

    // MARK: - 格子狀態色彩 (大幅增強已翻開/未翻開/已插旗之明暗反差)
    public static func hiddenCellTop(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.28, green: 0.33, blue: 0.44) // 凸起按鈕亮部 (高對比藍灰)
            : Color(red: 1.00, green: 1.00, blue: 1.00) // 純白高光按鈕頂部
    }

    public static func hiddenCellBottom(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.21, blue: 0.29) // 凸起按鈕暗部
            : Color(red: 0.91, green: 0.93, blue: 0.96) // 清晰淺灰過渡
    }

    public static func revealedCellBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.12) // 明顯凹陷深邃平底 (與未翻開有強烈反差)
            : Color(red: 0.82, green: 0.84, blue: 0.88) // 明顯凹陷啞光灰底 (純白未翻開相比極其明顯)
    }

    public static func flaggedCellTop(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.20, blue: 0.12) // 專屬戰術警示琥珀暖棕 (深色)
            : Color(red: 1.00, green: 0.94, blue: 0.84) // 溫潤暖金杏黃 (淺色)
    }

    public static func flaggedCellBottom(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.22, green: 0.11, blue: 0.07) // 警示漸層底層
            : Color(red: 0.98, green: 0.84, blue: 0.68)
    }

    // MARK: - 數字 1～8 經典高辨識度配色
    public static func numberColor(for count: Int) -> Color {
        switch count {
        case 1: return Color(red: 0.23, green: 0.51, blue: 0.96) // 藍色
        case 2: return Color(red: 0.13, green: 0.70, blue: 0.44) // 翡翠綠
        case 3: return Color(red: 0.93, green: 0.27, blue: 0.24) // 亮紅
        case 4: return Color(red: 0.49, green: 0.30, blue: 0.85) // 靛紫
        case 5: return Color(red: 0.75, green: 0.15, blue: 0.20) // 勃艮第深紅
        case 6: return Color(red: 0.10, green: 0.71, blue: 0.78) // 湖水青
        case 7: return Color(red: 0.80, green: 0.80, blue: 0.85) // 灰石
        case 8: return Color(red: 0.55, green: 0.60, blue: 0.68) // 灰藍
        default: return .primary
        }
    }
}
