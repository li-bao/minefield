import Foundation
import Combine

/// 遊戲操作歷史管理與復原重做引擎 (Undo / Redo Manager)
public final class UndoRedoManager: ObservableObject {
    public static let shared = UndoRedoManager()

    @Published public private(set) var undoStack: [GameSnapshot] = []
    @Published public private(set) var redoStack: [GameSnapshot] = []

    public let maxHistoryDepth: Int

    public init(maxHistoryDepth: Int = 100) {
        self.maxHistoryDepth = maxHistoryDepth
    }

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// 記錄新操作前的狀態快照
    public func recordSnapshot(_ snapshot: GameSnapshot) {
        undoStack.append(snapshot)
        if undoStack.count > maxHistoryDepth {
            undoStack.removeFirst()
        }
        // 新動作執行後清空 redo 棧
        redoStack.removeAll()
    }

    /// 執行復原 (Undo)
    /// - Parameter currentSnapshot: 當前狀態快照 (將壓入 redoStack)
    /// - Returns: 欲還原的前一狀態快照
    public func performUndo(currentSnapshot: GameSnapshot) -> GameSnapshot? {
        guard let previous = undoStack.popLast() else {
            return nil
        }
        redoStack.append(currentSnapshot)
        return previous
    }

    /// 執行重做 (Redo)
    /// - Parameter currentSnapshot: 當前狀態快照 (將壓入 undoStack)
    /// - Returns: 欲前進的次一狀態快照
    public func performRedo(currentSnapshot: GameSnapshot) -> GameSnapshot? {
        guard let next = redoStack.popLast() else {
            return nil
        }
        undoStack.append(currentSnapshot)
        return next
    }

    /// 清空所有歷史紀錄
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
