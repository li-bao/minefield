import AppKit
import SwiftUI

/// 針對 macOS 精確區分滑鼠「短按、長按、右鍵點擊」的輕量透明 AppKit 互動圖層 (不包覆 SwiftUI，保證純原生即時更新)
public struct MouseInteractionOverlay: NSViewRepresentable {
    public let longPressDuration: TimeInterval
    public let onShortClick: () -> Void
    public let onLongPress: () -> Void
    public let onRightClick: () -> Void
    public let onHoverChanged: ((Bool) -> Void)?
    public let onPressProgress: ((Double) -> Void)?

    public init(
        longPressDuration: TimeInterval = 0.45,
        onShortClick: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        onRightClick: @escaping () -> Void,
        onHoverChanged: ((Bool) -> Void)? = nil,
        onPressProgress: ((Double) -> Void)? = nil
    ) {
        self.longPressDuration = longPressDuration
        self.onShortClick = onShortClick
        self.onLongPress = onLongPress
        self.onRightClick = onRightClick
        self.onHoverChanged = onHoverChanged
        self.onPressProgress = onPressProgress
    }

    public func makeNSView(context: Context) -> CustomMouseOverlayNSView {
        let view = CustomMouseOverlayNSView()
        view.longPressDuration = longPressDuration
        view.onShortClick = onShortClick
        view.onLongPress = onLongPress
        view.onRightClick = onRightClick
        view.onHoverChanged = onHoverChanged
        view.onPressProgress = onPressProgress
        return view
    }

    public func updateNSView(_ nsView: CustomMouseOverlayNSView, context: Context) {
        nsView.longPressDuration = longPressDuration
        nsView.onShortClick = onShortClick
        nsView.onLongPress = onLongPress
        nsView.onRightClick = onRightClick
        nsView.onHoverChanged = onHoverChanged
        nsView.onPressProgress = onPressProgress
    }
}

/// 透明點擊攔截 NSView
public final class CustomMouseOverlayNSView: NSView {
    var longPressDuration: TimeInterval = 0.45
    var onShortClick: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onPressProgress: ((Double) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var pressTimer: Timer?
    private var progressTimer: Timer?
    private var pressStartTime: Date?
    private var didTriggerLongPress = false

    override public var isOpaque: Bool { false }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override public func menu(for event: NSEvent) -> NSMenu? {
        // 防止系統預設選單攔截右鍵插旗點擊
        nil
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override public func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override public func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        cancelTimers()
        onHoverChanged?(false)
    }

    override public func mouseDown(with event: NSEvent) {
        // 支援 Mac 觸控板與鍵盤慣例：按住 Control / Option / Command + 左鍵點擊即為插旗
        if event.modifierFlags.contains(.control) ||
           event.modifierFlags.contains(.option) ||
           event.modifierFlags.contains(.command) {
            cancelTimers()
            didTriggerLongPress = false
            onPressProgress?(0.0)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            onRightClick?()
            return
        }

        didTriggerLongPress = false
        pressStartTime = Date()

        // 啟動長按檢測計時器
        cancelTimers()
        pressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.didTriggerLongPress = true
            self.onPressProgress?(1.0)
            self.cancelTimers()

            // 觸發長按回饋與震動
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            self.onLongPress?()
        }

        // 啟動進度更新計時器 (每 16ms 刷新進度條)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.pressStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1.0, elapsed / self.longPressDuration)
            self.onPressProgress?(progress)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        let wasLongPress = didTriggerLongPress
        cancelTimers()

        if !wasLongPress {
            // 確認釋放時滑鼠仍在格子區域內
            let pointInView = convert(event.locationInWindow, from: nil)
            if bounds.contains(pointInView) {
                onShortClick?()
            }
        }
        didTriggerLongPress = false
        onPressProgress?(0.0)
    }

    override public func rightMouseDown(with event: NSEvent) {
        cancelTimers()
        didTriggerLongPress = false
        onPressProgress?(0.0)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        onRightClick?()
    }

    override public func otherMouseDown(with event: NSEvent) {
        // 中鍵點擊 (滾輪按鈕) 支援快速 Chording
        cancelTimers()
        didTriggerLongPress = false
        onPressProgress?(0.0)
        onShortClick?()
    }

    private func cancelTimers() {
        pressTimer?.invalidate()
        pressTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        pressStartTime = nil
    }
}

/// 針對 macOS 客製化之純 SwiftUI 互動容器（內部透過透明 Overlay 攔截滑鼠事件，徹底解決 NSHostingView 延遲不重繪問題）
public struct MouseInteractionView<Content: View>: View {
    private let content: Content
    private let longPressDuration: TimeInterval
    private let onShortClick: () -> Void
    private let onLongPress: () -> Void
    private let onRightClick: () -> Void
    private let onHoverChanged: ((Bool) -> Void)?
    private let onPressProgress: ((Double) -> Void)?

    public init(
        longPressDuration: TimeInterval = 0.45,
        onShortClick: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        onRightClick: @escaping () -> Void,
        onHoverChanged: ((Bool) -> Void)? = nil,
        onPressProgress: ((Double) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.longPressDuration = longPressDuration
        self.onShortClick = onShortClick
        self.onLongPress = onLongPress
        self.onRightClick = onRightClick
        self.onHoverChanged = onHoverChanged
        self.onPressProgress = onPressProgress
        self.content = content()
    }

    public var body: some View {
        content
            .overlay(
                MouseInteractionOverlay(
                    longPressDuration: longPressDuration,
                    onShortClick: onShortClick,
                    onLongPress: onLongPress,
                    onRightClick: onRightClick,
                    onHoverChanged: onHoverChanged,
                    onPressProgress: onPressProgress
                )
            )
    }
}
