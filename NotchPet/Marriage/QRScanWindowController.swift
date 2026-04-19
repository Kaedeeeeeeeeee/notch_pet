import AVFoundation
import AppKit

/// Hosts an `AVCaptureSession` inside a regular activating NSWindow so
/// the system has a key window available for camera frame updates. The
/// NotchPanel itself is `.nonactivatingPanel` and can't host a preview
/// layer reliably. When a QR code is detected, the window closes and
/// the detected string is handed back via `onDetected`.
@MainActor
final class QRScanWindowController: NSObject, NSWindowDelegate,
                                     AVCaptureMetadataOutputObjectsDelegate {
    static let shared = QRScanWindowController()

    private var window: NSWindow?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var onDetected: ((String) -> Void)?

    /// Open the scan window. `onDetected` fires on the main actor with
    /// the first QR string found; the window closes automatically.
    /// `onCancel` fires if the user closes the window without scanning.
    func start(onDetected: @escaping (String) -> Void,
               onCancel: @escaping () -> Void = {}) {
        // Already showing — bring to front.
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        self.onDetected = { [weak self] code in
            onDetected(code)
            self?.stop()
        }

        NSApp.activate(ignoringOtherApps: true)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = AppSettings.shared.language.marriageScanWindowTitle
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self

        // A plain NSView hosting the preview layer.
        let host = NSView(frame: w.contentLayoutRect)
        host.wantsLayer = true
        host.layer = CALayer()
        host.layer?.backgroundColor = NSColor.black.cgColor
        w.contentView = host

        self.window = w

        do {
            try configureSession(hostView: host)
        } catch {
            // Camera unavailable / permission denied — surface an alert
            // and close the window.
            showCameraErrorAlert(error: error)
            stop()
            onCancel()
            return
        }

        w.makeKeyAndOrderFront(nil)
        session?.startRunning()
    }

    func stop() {
        session?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        session = nil
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        onDetected = nil
    }

    // MARK: - Capture setup

    private func configureSession(hostView: NSView) throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CaptureError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)

        let session = AVCaptureSession()
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr)
            ? [.qr]
            : output.availableMetadataObjectTypes
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = hostView.bounds
        preview.needsDisplayOnBoundsChange = true
        hostView.layer?.addSublayer(preview)
        hostView.postsFrameChangedNotifications = true

        self.session = session
        self.previewLayer = preview
    }

    // MARK: - Delegate: first QR detected

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readable = metadataObjects
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first,
              let value = readable.stringValue else { return }
        Task { @MainActor [weak self] in
            self?.onDetected?(value)
        }
    }

    // MARK: - Window close handling

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.stop() }
    }

    // MARK: - Error alerts

    private func showCameraErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = AppSettings.shared.language.marriageScanCameraError
        alert.informativeText = (error as CustomStringConvertible).description
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private enum CaptureError: Error, CustomStringConvertible {
        case noCamera
        var description: String {
            switch self {
            case .noCamera: return "No camera device available."
            }
        }
    }
}
