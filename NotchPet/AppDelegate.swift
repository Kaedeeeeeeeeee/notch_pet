import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.builtInNotchedScreen, screen.notchSize != nil else {
            presentNoNotchAlertAndQuit()
            return
        }
        let controller = NotchPanelController(screen: screen)
        controller.show()
        self.panelController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func presentNoNotchAlertAndQuit() {
        let alert = NSAlert()
        alert.messageText = "未检测到刘海"
        alert.informativeText = "Notch Pet 目前仅支持带刘海的 MacBook（macOS 15+）。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
