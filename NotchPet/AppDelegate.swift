import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var petState: PetState?
    private var store: PetStateStore?
    private var timeService: TimeService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.builtInNotchedScreen, screen.notchSize != nil else {
            presentNoNotchAlertAndQuit()
            return
        }

        let store = PetStateStore()
        let petState = store.load()
        let timeService = TimeService(petState: petState, store: store)

        let controller = NotchPanelController(screen: screen, petState: petState)
        controller.show()
        timeService.start()

        self.store = store
        self.petState = petState
        self.timeService = timeService
        self.panelController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        timeService?.flush()
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
