import SwiftUI

/// 單一格子的視覺高亮標記類型 (智慧排雷與提示系統專用)
public enum CellHighlight: Equatable {
    case none
    case safe
    case mine
    case guess(risk: Double)
    case target
}

/// 單一掃雷格子原生視覺元件 (高反差 3D 質感、清晰翻開/未翻開區隔與專屬插旗方塊)
public struct CellView: View {
    @Environment(\.colorScheme) private var colorScheme

    public let cell: Cell
    public let cellSize: CGFloat
    public let longPressDuration: TimeInterval
    public let highlight: CellHighlight
    public let onReveal: () -> Void
    public let onToggleFlag: () -> Void
    public let onChord: () -> Void

    @State private var isHovered = false
    @State private var pressProgress: Double = 0.0

    public init(
        cell: Cell,
        cellSize: CGFloat = 32,
        longPressDuration: TimeInterval = 0.45,
        highlight: CellHighlight = .none,
        onReveal: @escaping () -> Void,
        onToggleFlag: @escaping () -> Void,
        onChord: @escaping () -> Void
    ) {
        self.cell = cell
        self.cellSize = cellSize
        self.longPressDuration = longPressDuration
        self.highlight = highlight
        self.onReveal = onReveal
        self.onToggleFlag = onToggleFlag
        self.onChord = onChord
    }

    public var body: some View {
        MouseInteractionView(
            longPressDuration: longPressDuration,
            onShortClick: {
                if cell.isRevealed {
                    onChord()
                } else if cell.isHidden {
                    onReveal()
                }
            },
            onLongPress: {
                if cell.isHidden || cell.isFlagged {
                    onToggleFlag()
                }
            },
            onRightClick: {
                if cell.isHidden || cell.isFlagged {
                    onToggleFlag()
                }
            },
            onHoverChanged: { hovered in
                isHovered = hovered
            },
            onPressProgress: { progress in
                pressProgress = progress
            }
        ) {
            ZStack {
                // 背景基底 (未翻開 3D 凸起 / 已翻開凹陷平坦 / 已插旗專屬警示方塊)
                cellBackground

                // 格子內部內容 (旗幟、數字、地雷或爆炸效果)
                cellContent

                // 長按充能環指示器 (提示即將插旗/拔旗)
                if pressProgress > 0.0 && (cell.isHidden || cell.isFlagged) {
                    let cornerRadius: CGFloat = max(3.5, cellSize * 0.14)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            ColorTheme.amberWarning,
                            lineWidth: 2.5
                        )
                        .padding(1)
                        .opacity(pressProgress)
                        .animation(.linear(duration: 0.05), value: pressProgress)
                }

                // 智慧排雷與提示高亮光環
                if cell.isHidden {
                    highlightOverlay
                }
            }
            .frame(width: cellSize, height: cellSize)
            .scaleEffect(isHovered && cell.isHidden ? 1.05 : (pressProgress > 0 ? 0.95 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: pressProgress)
            .focusable(false)
            .onKeyPress(.space) {
                if isHovered && (cell.isHidden || cell.isFlagged) {
                    onToggleFlag()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "fF")) { _ in
                if isHovered && (cell.isHidden || cell.isFlagged) {
                    onToggleFlag()
                    return .handled
                }
                return .ignored
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    // MARK: - 背景樣式 (大幅拉開「已翻開」與「未翻開」的明暗反差，並給予「已插旗」專屬色彩)
    @ViewBuilder
    private var cellBackground: some View {
        let cornerRadius: CGFloat = max(3.5, cellSize * 0.14)

        switch cell.state {
        case .hidden:
            // 1. 未翻開：極具實體感之立體凸起 3D 按鈕
            ZStack {
                // 按鈕本體漸層
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTheme.hiddenCellTop(for: colorScheme),
                                ColorTheme.hiddenCellBottom(for: colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 3D 頂部與左側高光邊緣 + 底部右側立體陰影邊緣
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.32) : Color.white, location: 0.0),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.6), location: 0.35),
                                .init(color: colorScheme == .dark ? Color.black.opacity(0.40) : Color(red: 0.70, green: 0.74, blue: 0.80), location: 0.65),
                                .init(color: colorScheme == .dark ? Color.black.opacity(0.55) : Color(red: 0.62, green: 0.66, blue: 0.74), location: 1.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.0, cellSize * 0.05)
                    )

                // 滑鼠懸停時之柔和動態高光
                if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(ColorTheme.mintAccent.opacity(0.7), lineWidth: 1.5)
                        .shadow(color: ColorTheme.mintAccent.opacity(0.4), radius: 3)
                }
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14),
                radius: isHovered ? 3.5 : 1.8,
                x: 0,
                y: isHovered ? 2.5 : 1.2
            )

        case .flagged:
            // 2. 已插旗方塊：專屬暖琥珀/金黃戰術警示方塊 (整塊方格一眼即可識別)
            ZStack {
                // 專屬警示漸層底色
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTheme.flaggedCellTop(for: colorScheme),
                                ColorTheme.flaggedCellBottom(for: colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 醒目的立體金黃警示邊框
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        ColorTheme.amberWarning,
                        lineWidth: max(1.4, cellSize * 0.065)
                    )

                // 懸停時強調光暈
                if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                }
            }
            .shadow(
                color: ColorTheme.amberWarning.opacity(colorScheme == .dark ? 0.40 : 0.28),
                radius: isHovered ? 4.5 : 2.5,
                x: 0,
                y: 1.2
            )

        case .revealed:
            // 3. 已翻開：平坦凹陷之開挖地面質感 (無外陰影、內凹陰影邊緣、低亮度深邃平坦)
            ZStack {
                // 凹陷底色 (深色模式極深黑灰，淺色模式明顯灰階，與未翻開之亮白/亮灰強烈反差)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ColorTheme.revealedCellBackground(for: colorScheme))

                // 頂部與左側內凹陰影邊緣 (營造被挖開沉入地面的立體落差)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.black.opacity(0.75) : Color.black.opacity(0.22), location: 0.0),
                                .init(color: colorScheme == .dark ? Color.black.opacity(0.40) : Color.black.opacity(0.10), location: 0.35),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.35), location: 0.65),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55), location: 1.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )

                // 空白安全格 (0 雷) 之極微小凹痕裝飾，突顯「此格已被確認開挖並安全」
                if !cell.hasMine && cell.neighboringMines == 0 {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .frame(width: max(2.5, cellSize * 0.1), height: max(2.5, cellSize * 0.1))
                }
            }

        case .exploded:
            // 4. 踩雷爆炸特殊紅色漸層光暈
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTheme.crimsonExplosion,
                                Color(red: 0.85, green: 0.15, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
            }
            .shadow(color: ColorTheme.crimsonExplosion.opacity(0.8), radius: 8, x: 0, y: 0)
        }
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        let cornerRadius: CGFloat = max(3.5, cellSize * 0.14)
        switch highlight {
        case .none:
            EmptyView()
        case .safe:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ColorTheme.mintAccent, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(ColorTheme.mintAccent.opacity(0.18))
                )
        case .mine:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ColorTheme.amberWarning, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(ColorTheme.amberWarning.opacity(0.18))
                )
        case .guess(let risk):
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(red: 0.96, green: 0.62, blue: 0.15), lineWidth: 1.5)
                .overlay(
                    Text("\(Int(risk * 100))%")
                        .font(.system(size: max(8, cellSize * 0.28), weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTheme.amberWarning)
                )
        case .target:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ColorTheme.mintAccent, lineWidth: 2.5)
                .shadow(color: ColorTheme.mintAccent.opacity(0.8), radius: 4)
        }
    }

    // MARK: - 內容圖示與文字 (精緻立體旗標、清晰數字與地雷圖標)
    @ViewBuilder
    private var cellContent: some View {
        switch cell.state {
        case .hidden:
            EmptyView()

        case .flagged:
            // 精美立體旗標 (醒目鮮紅旗面 + 亮銀金屬旗桿 + 穩固基座)
            FlagMarkerView(size: cellSize * 0.68)
                .transition(.scale(scale: 0.6).combined(with: .opacity))

        case .revealed:
            if cell.hasMine {
                // 遊戲結束揭露全部地雷時
                MineIconView(size: cellSize * 0.62)
                    .transition(.scale)
            } else if cell.neighboringMines > 0 {
                Text("\(cell.neighboringMines)")
                    .font(.system(size: cellSize * 0.56, weight: .heavy, design: .rounded))
                    .foregroundStyle(ColorTheme.numberColor(for: cell.neighboringMines))
                    .shadow(
                        color: colorScheme == .dark
                            ? ColorTheme.numberColor(for: cell.neighboringMines).opacity(0.35)
                            : Color.clear,
                        radius: 2,
                        x: 0,
                        y: 0
                    )
                    .transition(.opacity)
            }

        case .exploded:
            ZStack {
                Image(systemName: "burst.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cellSize * 0.65, height: cellSize * 0.65)
                    .foregroundStyle(.white)

                Image(systemName: "circle.hexagongrid.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cellSize * 0.38, height: cellSize * 0.38)
                    .foregroundStyle(.black)
            }
            .transition(.scale)
        }
    }

    private var accessibilityText: String {
        switch cell.state {
        case .hidden:
            return "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，未翻開"
        case .flagged:
            return "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，已插旗標記地雷"
        case .revealed:
            if cell.hasMine {
                return "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，地雷格"
            }
            return cell.neighboringMines > 0
                ? "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，周圍有 \(cell.neighboringMines) 顆地雷"
                : "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，空白安全格"
        case .exploded:
            return "第 \(cell.row + 1) 列，第 \(cell.column + 1) 行，地雷已引爆"
        }
    }
}

// MARK: - 專屬高辨識度立體旗標元件 (FlagMarkerView)
public struct FlagMarkerView: View {
    public let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            // 1. 金屬旗桿 (垂直桿身)
            let poleX = w * 0.34
            let poleWidth = max(1.8, w * 0.08)
            let poleRect = CGRect(
                x: poleX - (poleWidth * 0.5),
                y: h * 0.12,
                width: poleWidth,
                height: h * 0.70
            )
            let polePath = Path(roundedRect: poleRect, cornerRadius: poleWidth * 0.5)
            context.fill(polePath, with: .color(Color(white: 0.94)))

            // 旗桿頂部金色球飾 (Finial)
            let ballSize = max(3.0, w * 0.16)
            let ballRect = CGRect(
                x: poleX - (ballSize * 0.5),
                y: h * 0.06,
                width: ballSize,
                height: ballSize
            )
            context.fill(Path(ellipseIn: ballRect), with: .color(Color(red: 1.0, green: 0.82, blue: 0.20)))

            // 2. 鮮紅三角三角旗面 (向右飄揚)
            var flagPath = Path()
            flagPath.move(to: CGPoint(x: poleX + (poleWidth * 0.4), y: h * 0.15))
            flagPath.addLine(to: CGPoint(x: w * 0.90, y: h * 0.38))
            flagPath.addLine(to: CGPoint(x: poleX + (poleWidth * 0.4), y: h * 0.60))
            flagPath.closeSubpath()

            let flagGradient = Gradient(colors: [
                Color(red: 0.96, green: 0.22, blue: 0.20), // 鮮亮赤紅
                Color(red: 0.82, green: 0.12, blue: 0.12)  // 陰影深紅
            ])
            context.fill(
                flagPath,
                with: .linearGradient(
                    flagGradient,
                    startPoint: CGPoint(x: poleX, y: h * 0.15),
                    endPoint: CGPoint(x: w * 0.90, y: h * 0.38)
                )
            )

            // 旗面高光折線
            var foldPath = Path()
            foldPath.move(to: CGPoint(x: poleX + (poleWidth * 0.4), y: h * 0.15))
            foldPath.addLine(to: CGPoint(x: w * 0.90, y: h * 0.38))
            context.stroke(foldPath, with: .color(Color.white.opacity(0.4)), lineWidth: 1.0)

            // 3. 穩固金屬底座 (基石)
            let baseWidth = w * 0.58
            let baseHeight = max(2.5, h * 0.12)
            let baseRect = CGRect(
                x: poleX - (baseWidth * 0.5),
                y: h * 0.78,
                width: baseWidth,
                height: baseHeight
            )
            let basePath = Path(roundedRect: baseRect, cornerRadius: baseHeight * 0.45)
            context.fill(basePath, with: .color(Color(white: 0.24)))
            context.stroke(basePath, with: .color(Color.black.opacity(0.4)), lineWidth: 0.8)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.94, green: 0.22, blue: 0.20).opacity(0.55), radius: 2.5, x: 0, y: 1.2)
    }
}

// MARK: - 地雷圖示元件 (MineIconView)
public struct MineIconView: View {
    public let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Image(systemName: "circle.hexagongrid.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Color.primary.opacity(0.85))
    }
}
