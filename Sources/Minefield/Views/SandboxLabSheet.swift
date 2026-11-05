import SwiftUI

/// 沙盒實驗室面板視圖 (Sandbox Lab Sheet)
public struct SandboxLabSheet: View {
    public let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engine = SandboxLabEngine()
    @State private var shareCodeText: String = ""
    @State private var importErrorMessage: String?
    @State private var copiedFeedback: Bool = false

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(ColorTheme.mintAccent)
                    .font(.system(size: 20))
                Text("沙盒棋局實驗室 (Sandbox Lab)")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Text("自由擺放地雷、測試 Solver 推導、驗證 No-Guess 無猜性質，並支援匯入/匯出安全棋局分享碼。\n沙盒實驗不計入正式競速戰績。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            Divider()

            // 編輯區域
            HStack(alignment: .top, spacing: 16) {
                // 左側：網格編輯器
                VStack(spacing: 8) {
                    HStack {
                        Text("網格編輯器 (\(engine.board.rows)×\(engine.board.columns))")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("地雷總數: \(countMines())")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }

                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 2) {
                            ForEach(0..<engine.board.rows, id: \.self) { r in
                                HStack(spacing: 2) {
                                    ForEach(0..<engine.board.columns, id: \.self) { c in
                                        let cell = engine.board[r, c]
                                        Button(action: {
                                            engine.toggleMine(row: r, column: c)
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(cell.hasMine ? Color.red.opacity(0.35) : Color.gray.opacity(0.2))
                                                    .frame(width: 26, height: 26)
                                                if cell.hasMine {
                                                    Image(systemName: "circle.hexagongrid.fill")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(Color.red)
                                                } else if cell.neighboringMines > 0 {
                                                    Text("\(cell.neighboringMines)")
                                                        .font(.system(size: 11, weight: .bold))
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(8)
                    }
                    .frame(height: 250)

                    Text("提示：點擊任一方格可切換是否埋設地雷。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 320)

                Divider()

                // 右側：Solver 演算法測試與分析結果
                VStack(alignment: .leading, spacing: 12) {
                    Text("演算法實驗與檢驗")
                        .font(.system(size: 13, weight: .bold))

                    HStack(spacing: 10) {
                        Button("執行 CSP 求解") {
                            _ = engine.runSolverAnalysis()
                        }
                        .buttonStyle(.bordered)

                        Button("無猜路徑驗證") {
                            _ = engine.verifyNoGuess(firstClick: GridCoordinate(0, 0))
                        }
                        .buttonStyle(.bordered)
                    }

                    if let sol = engine.lastSolverResult {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("求解器狀態：\(sol.status.rawValue)")
                                .font(.system(size: 12, weight: .bold))
                            Text("確定安全: \(sol.sureSafeCells.count) 格 ｜ 確定地雷: \(sol.sureMineCells.count) 顆")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTheme.cardBackground(for: colorScheme))
                        .cornerRadius(8)
                    }

                    if let isNoGuess = engine.isSolvableWithoutGuess {
                        HStack {
                            Image(systemName: isNoGuess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isNoGuess ? ColorTheme.mintAccent : Color.orange)
                            Text(isNoGuess ? "此自訂棋盤【存在】完整無猜解題路徑！" : "此自訂棋盤【不存在】完整無猜解題路徑。")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(10)
                        .background(isNoGuess ? ColorTheme.mintAccent.opacity(0.12) : Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    Spacer()

                    // 分享碼管理
                    VStack(alignment: .leading, spacing: 6) {
                        Text("棋局分享碼 (不外洩隱藏地雷)")
                            .font(.system(size: 12, weight: .bold))
                        HStack {
                            TextField("輸入或貼上分享碼...", text: $shareCodeText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                            Button("匯入") {
                                importCode()
                            }
                            .buttonStyle(.bordered)

                            Button(copiedFeedback ? "已複製！" : "匯出代碼") {
                                exportCode()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let err = importErrorMessage {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.red)
                        }
                    }
                }
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()
                Button("關閉") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 680, height: 500)
        .background(ColorTheme.windowBackground(for: colorScheme))
    }

    private func countMines() -> Int {
        var count = 0
        for r in 0..<engine.board.rows {
            for c in 0..<engine.board.columns {
                if engine.board[r, c].hasMine { count += 1 }
            }
        }
        return count
    }

    private func exportCode() {
        let code = engine.exportShareCode()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        shareCodeText = code
        copiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            copiedFeedback = false
        }
    }

    private func importCode() {
        importErrorMessage = nil
        switch engine.importShareCode(shareCodeText) {
        case .success:
            break
        case .failure(let err):
            importErrorMessage = err.localizedDescription
        }
    }
}
