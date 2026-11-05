import SwiftUI

/// 棋盤修復預覽與確認套用視窗 (AI Board Repair Preview)
public struct BoardRepairSheet: View {
    public let currentBoard: Board
    public let repairResult: BoardRepairResult
    public let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(
        currentBoard: Board,
        repairResult: BoardRepairResult,
        onApply: @escaping () -> Void
    ) {
        self.currentBoard = currentBoard
        self.repairResult = repairResult
        self.onApply = onApply
    }

    public var body: some View {
        VStack(spacing: 20) {
            // 標題列
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTheme.mintAccent)
                Text("AI 棋局防猜修復預覽")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                verificationBadge
            }

            ScrollView {
                VStack(spacing: 16) {
                    // 修復核心摘要卡
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("修復策略與目標")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("移動地雷: \(repairResult.movedMinesCount) 顆")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(ColorTheme.amberWarning)
                        }

                        if repairResult.success {
                            Text("偵測到局部對稱猜測僵局 (GUESS_REQUIRED)。已透過「等價足跡置換」演算法，在 100% 保持既有已揭露數字不變的前提下微調地雷分佈，創造出必然安全格。")
                                .font(.system(size: 13))
                                .lineSpacing(2)
                        } else {
                            Text(repairResult.errorMessage ?? "無法修復當前棋局。")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTheme.crimsonExplosion)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTheme.cardBackground(for: colorScheme))
                    )

                    // 地雷移動計畫明細
                    if !repairResult.moves.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("微調移動明細 (Minimal Changes)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)

                            ForEach(repairResult.moves) { move in
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "burst.fill")
                                            .foregroundStyle(ColorTheme.crimsonExplosion)
                                        Text("移除雷 (\(move.from.row),\(move.from.column))")
                                    }
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(ColorTheme.amberWarning)
                                        Text("重置至 (\(move.to.row),\(move.to.column))")
                                    }
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.04))
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTheme.cardBackground(for: colorScheme))
                        )
                    }

                    // 新增必然安全步
                    if !repairResult.newSafeCells.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ColorTheme.mintAccent)
                                Text("解鎖之必然安全格")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            HStack(spacing: 8) {
                                ForEach(repairResult.newSafeCells) { coord in
                                    Text("(\(coord.row), \(coord.column))")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(ColorTheme.mintAccent.opacity(0.2))
                                        )
                                        .foregroundStyle(ColorTheme.mintAccent)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTheme.cardBackground(for: colorScheme))
                        )
                    }

                    // 交易驗證清單
                    VStack(alignment: .leading, spacing: 8) {
                        Text("交易式完整性審查 (Transaction Audit)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)

                        ForEach(repairResult.validationNotes, id: \.self) { note in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(ColorTheme.mintAccent)
                                Text(note)
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ColorTheme.cardBackground(for: colorScheme))
                    )
                }
            }

            // 底部操作按鈕
            HStack(spacing: 14) {
                Button("取消 (Cancel)") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))

                Spacer()

                Button("套用修復 (Apply Repair)") {
                    onApply()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.mintAccent)
                .foregroundStyle(.black)
                .fontWeight(.bold)
                .disabled(!repairResult.success)
            }
        }
        .padding(26)
        .frame(width: 520, height: 580)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    @ViewBuilder
    private var verificationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: repairResult.success ? "checkmark.seal.fill" : "xmark.seal.fill")
            Text(repairResult.success ? "數學審查通過" : "無法安全修復")
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(repairResult.success ? ColorTheme.mintAccent.opacity(0.18) : ColorTheme.crimsonExplosion.opacity(0.18))
        )
        .foregroundStyle(repairResult.success ? ColorTheme.mintAccent : ColorTheme.crimsonExplosion)
    }
}
