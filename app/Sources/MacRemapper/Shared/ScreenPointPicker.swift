import AppKit

/// Lets the user pick a point anywhere on screen: covers every display with a translucent
/// overlay and a crosshair cursor, and reports the clicked point in global display
/// coordinates (origin at the top-left of the main display, as mouse events use).
/// Escape cancels.
enum ScreenPointPicker {
    private static var windows: [NSWindow] = []
    private static var completion: ((CGPoint) -> Void)?

    static func pick(completion: @escaping (CGPoint) -> Void) {
        finish(with: nil)
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            window.setFrame(screen.frame, display: true)
            window.makeFirstResponder(window.contentView) // so Escape reaches the overlay
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }
        (windows.first { $0.screen == NSScreen.main } ?? windows.first)?.makeKey()
    }

    fileprivate static func finish(with point: CGPoint?) {
        let completion = self.completion
        self.completion = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if let point { completion?(point) }
    }

    /// Converts AppKit's bottom-left-origin screen coordinates to the top-left-origin
    /// global coordinates that CGEvent mouse positions use.
    fileprivate static func globalPoint(fromScreenPoint point: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: point.x.rounded(), y: (primaryHeight - point.y).rounded())
    }

    private final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }

    private final class OverlayView: NSView {
        private var pointer: NSPoint?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate],
                                           owner: self, userInfo: nil))
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .crosshair)
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.crosshair.set()
        }

        override func mouseMoved(with event: NSEvent) {
            pointer = convert(event.locationInWindow, from: nil)
            needsDisplay = true
        }

        override func mouseDown(with event: NSEvent) {
            ScreenPointPicker.finish(with: ScreenPointPicker.globalPoint(fromScreenPoint: NSEvent.mouseLocation))
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Escape
                ScreenPointPicker.finish(with: nil)
            }
        }

        override var acceptsFirstResponder: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.withAlphaComponent(0.18).setFill()
            bounds.fill()

            drawBadge("Click anywhere to pick a position  ·  Esc to cancel",
                      centeredAt: NSPoint(x: bounds.midX, y: bounds.maxY - 80))

            if let pointer, let window {
                let global = ScreenPointPicker.globalPoint(fromScreenPoint: window.convertPoint(toScreen: pointer))
                drawBadge("x \(Int(global.x))   y \(Int(global.y))",
                          centeredAt: NSPoint(x: pointer.x + 60, y: pointer.y - 28))
            }
        }

        private func drawBadge(_ text: String, centeredAt center: NSPoint) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            let rect = NSRect(x: center.x - size.width / 2 - 10, y: center.y - size.height / 2 - 5,
                              width: size.width + 20, height: size.height + 10)
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
            (text as NSString).draw(at: NSPoint(x: rect.minX + 10, y: rect.minY + 5), withAttributes: attributes)
        }
    }
}
