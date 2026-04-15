import AppKit

extension NSScreen {
    /// Returns the size of the MacBook notch for this screen, or nil if the screen
    /// has no notch. Notch height is read from safeAreaInsets.top (public API since
    /// macOS 12). Width is derived from the gap between auxiliaryTopLeftArea and
    /// auxiliaryTopRightArea when available, otherwise falls back to a model-typical
    /// value.
    var notchSize: CGSize? {
        let insetTop = safeAreaInsets.top
        guard insetTop > 0 else { return nil }

        let left = auxiliaryTopLeftArea
        let right = auxiliaryTopRightArea

        let derivedWidth: CGFloat
        if let left, let right {
            let gap = right.minX - left.maxX
            derivedWidth = gap > 0 ? gap : Self.fallbackNotchWidth
        } else {
            derivedWidth = Self.fallbackNotchWidth
        }

        return CGSize(width: derivedWidth, height: insetTop)
    }

    /// Frame in screen coordinates of the notch itself (menu-bar aligned).
    var notchFrame: CGRect? {
        guard let size = notchSize else { return nil }
        let midX = frame.midX
        let topY = frame.maxY
        return CGRect(
            x: midX - size.width / 2,
            y: topY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static let fallbackNotchWidth: CGFloat = 200

    /// Pick the screen that physically owns the MacBook notch, regardless of
    /// which display the user has marked as "main". When the MacBook is the
    /// only screen this is the same as `NSScreen.main`; when external displays
    /// are attached and one of them is set as primary, this walks all screens
    /// and returns the first one that reports a non-zero top safe area inset.
    static var builtInNotchedScreen: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 }
    }
}
