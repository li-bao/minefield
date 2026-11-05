import Foundation
import SwiftUI

/// 管理遊戲過程中的邏輯推理歷史紀錄
public final class ReasoningHistoryManager: ObservableObject {
    public static let shared = ReasoningHistoryManager()

    @Published public private(set) var history: [ReasoningStep] = []

    public init() {}

    public func addStep(_ step: ReasoningStep) {
        DispatchQueue.main.async {
            self.history.insert(step, at: 0) // 最新的在最上方
            if self.history.count > 100 {
                self.history.removeLast()
            }
        }
    }

    public func clear() {
        DispatchQueue.main.async {
            self.history.removeAll()
        }
    }
}
