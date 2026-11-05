import SwiftUI

/// 自訂棋盤設定視窗
public struct CustomBoardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var width: Int
    @State private var height: Int
    @State private var mines: Int

    public let onConfirm: (CustomBoardConfig) -> Void

    public init(
        currentConfig: CustomBoardConfig = CustomBoardConfig(width: 16, height: 16, mines: 40),
        onConfirm: @escaping (CustomBoardConfig) -> Void
    ) {
        self._width = State(initialValue: currentConfig.width)
        self._height = State(initialValue: currentConfig.height)
        self._mines = State(initialValue: currentConfig.mines)
        self.onConfirm = onConfirm
    }

    private var maxAllowedMines: Int {
        CustomBoardConfig.maxMines(forWidth: width, height: height)
    }

    private var densityPercentage: Double {
        let total = width * height
        guard total > 0 else { return 0.0 }
        return (Double(mines) / Double(total)) * 100.0
    }

    private var validationResult: Result<CustomBoardConfig, CustomBoardValidationError> {
        CustomBoardConfig.validate(width: width, height: height, mines: mines)
    }

    public var body: some View {
        VStack(spacing: 24) {
            // 標題與簡介
            VStack(spacing: 6) {
                Text("自訂掃雷棋盤")
                    .font(.system(size: 20, weight: .bold))
                Text("自由微調棋盤尺寸與地雷總數，打造專屬難度")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // 參數設定卡片
            VStack(spacing: 16) {
                // 寬度
                parameterRow(
                    title: "棋盤寬度 (行數)",
                    value: $width,
                    range: CustomBoardConfig.minWidth...CustomBoardConfig.maxWidth,
                    unit: "格"
                )

                Divider()

                // 高度
                parameterRow(
                    title: "棋盤高度 (列數)",
                    value: $height,
                    range: CustomBoardConfig.minHeight...CustomBoardConfig.maxHeight,
                    unit: "格"
                )

                Divider()

                // 地雷數量
                parameterRow(
                    title: "地雷總數",
                    value: $mines,
                    range: 1...max(1, maxAllowedMines),
                    unit: "顆"
                )
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.cardBackground(for: colorScheme))
            )

            // 地雷密度與難度分類標籤
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("地雷密度")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", densityPercentage))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }

                Spacer()

                // 分類標籤
                difficultyBadge(for: densityPercentage)
            }
            .padding(.horizontal, 12)

            // 錯誤訊息提示列
            if case let .failure(error) = validationResult {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(ColorTheme.crimsonExplosion)
                    Text(error.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTheme.crimsonExplosion)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.crimsonExplosion.opacity(0.12))
                )
            }

            // 底部操作按鈕
            HStack(spacing: 14) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.08))
                )

                Spacer()

                Button("生成棋盤並開始") {
                    if case let .success(config) = validationResult {
                        onConfirm(config)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.mintAccent)
                )
                .foregroundStyle(.black)
                .fontWeight(.semibold)
                .disabled({
                    if case .failure = validationResult { return true }
                    return false
                }())
                .opacity({
                    if case .failure = validationResult { return 0.5 }
                    return 1.0
                }())
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    @ViewBuilder
    private func parameterRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTheme.mintAccent)
            }

            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(value.wrappedValue) },
                        set: {
                            let newVal = Int($0)
                            value.wrappedValue = newVal
                            // 若寬高更動造成地雷數超標，自動截斷至上限
                            if mines > maxAllowedMines {
                                mines = maxAllowedMines
                            }
                        }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(ColorTheme.mintAccent)

                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private func difficultyBadge(for density: Double) -> some View {
        let (label, color) = difficultyInfo(for: density)

        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
        )
    }

    private func difficultyInfo(for density: Double) -> (String, Color) {
        if density < 12.0 {
            return ("休閒輕度", ColorTheme.mintAccent)
        } else if density < 18.0 {
            return ("標準均衡", Color(red: 0.23, green: 0.51, blue: 0.96))
        } else if density < 24.0 {
            return ("高難度挑戰", ColorTheme.amberWarning)
        } else {
            return ("極限地獄", ColorTheme.crimsonExplosion)
        }
    }
}
