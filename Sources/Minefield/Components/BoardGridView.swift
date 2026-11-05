import SwiftUI

/// 自適應掃雷棋盤網格視圖
public struct BoardGridView: View {
    @ObservedObject public var engine: GameEngine
    public let longPressDuration: TimeInterval
    public let highlights: [String: CellHighlight]
    @Environment(\.colorScheme) private var colorScheme

    public init(
        engine: GameEngine,
        longPressDuration: TimeInterval = 0.45,
        highlights: [String: CellHighlight] = [:]
    ) {
        self.engine = engine
        self.longPressDuration = longPressDuration
        self.highlights = highlights
    }

    public var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - 32
            let availableHeight = proxy.size.height - 32
            let cols = CGFloat(engine.internalBoard.columns)
            let rows = CGFloat(engine.internalBoard.rows)

            // 自動計算適合當前畫面的最佳格子大小 (界於 24px 至 44px 之間)
            let rawCellW = (availableWidth - (cols * 3)) / cols
            let rawCellH = (availableHeight - (rows * 3)) / rows
            let idealSize = min(rawCellW, rawCellH)
            let cellSize = max(24, min(44, idealSize))

            let gridTotalWidth = cols * (cellSize + 3)
            let gridTotalHeight = rows * (cellSize + 3)

            let needScroll = gridTotalWidth > availableWidth || gridTotalHeight > availableHeight

            if needScroll {
                ScrollView([.horizontal, .vertical]) {
                    gridContent(cellSize: cellSize)
                        .padding(16)
                }
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        gridContent(cellSize: cellSize)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func gridContent(cellSize: CGFloat) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<engine.internalBoard.rows, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<engine.internalBoard.columns, id: \.self) { c in
                        let cell = engine.internalBoard[r, c]
                        let hl = highlights["\(r),\(c)"] ?? .none
                        CellView(
                            cell: cell,
                            cellSize: cellSize,
                            longPressDuration: longPressDuration,
                            highlight: hl,
                            onReveal: {
                                engine.revealCell(atRow: r, column: c)
                            },
                            onToggleFlag: {
                                engine.toggleFlag(atRow: r, column: c)
                            },
                            onChord: {
                                engine.chordReveal(atRow: r, column: c)
                            }
                        )
                        .id("\(r),\(c),\(cell.state)")
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.gridBackground(for: colorScheme))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
    }
}
