import AppKit

final class SelectionView: NSView {
    var onSelectionFinished: ((CGRect?) -> Void)?

    private var startPointInScreen: CGPoint?
    private var selectionRectInScreen: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let window else { return }

        if let selectionRectInScreen {
            let selectionRect = window.convertFromScreen(selectionRectInScreen)

            let outsidePath = NSBezierPath(rect: bounds)
            outsidePath.append(NSBezierPath(rect: selectionRect))
            outsidePath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.45).setFill()
            outsidePath.fill()

            NSColor.white.withAlphaComponent(0.10).setFill()
            NSBezierPath(rect: selectionRect).fill()

            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 2
            NSColor.white.setStroke()
            borderPath.stroke()
        } else {
            NSColor.black.withAlphaComponent(0.45).setFill()
            bounds.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        let point = window.convertPoint(toScreen: event.locationInWindow)
        startPointInScreen = point
        selectionRectInScreen = CGRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPointInScreen, let window else { return }

        let currentPoint = window.convertPoint(toScreen: event.locationInWindow)
        selectionRectInScreen = CGRect.normalized(from: startPointInScreen, to: currentPoint)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPointInScreen, let window else {
            onSelectionFinished?(nil)
            return
        }

        let endPoint = window.convertPoint(toScreen: event.locationInWindow)
        let rect = CGRect.normalized(from: startPointInScreen, to: endPoint)

        self.startPointInScreen = nil
        selectionRectInScreen = nil
        needsDisplay = true

        if rect.width < 4 || rect.height < 4 {
            onSelectionFinished?(nil)
        } else {
            onSelectionFinished?(rect)
        }
    }
}

private extension CGRect {
    static func normalized(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
    }
}
