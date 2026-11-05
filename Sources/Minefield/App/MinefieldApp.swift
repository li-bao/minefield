import SwiftUI

@main
struct MinefieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 960, height: 720)
        .commands {
            // 遊戲原生選單指令
            CommandMenu("遊戲") {
                Button("重新開始此局") {
                    NotificationCenter.default.post(name: .restartGame, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("初級模式 (9×9)") {
                    NotificationCenter.default.post(name: .startBeginner, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("中級模式 (16×16)") {
                    NotificationCenter.default.post(name: .startIntermediate, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("高級模式 (30×16)") {
                    NotificationCenter.default.post(name: .startExpert, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

public extension Notification.Name {
    static let restartGame = Notification.Name("com.minefield.restartGame")
    static let startBeginner = Notification.Name("com.minefield.startBeginner")
    static let startIntermediate = Notification.Name("com.minefield.startIntermediate")
    static let startExpert = Notification.Name("com.minefield.startExpert")
}
