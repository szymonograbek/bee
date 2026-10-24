import AppKit

/// The menu bar icon: a bee seen from above, drawn in code so it stays crisp at any scale.
enum BeeGlyph {
    private static let size = NSSize(width: 18, height: 18)

    /// A template image, so the menu bar tints it for light, dark, and highlighted states.
    /// Awake draws a solid body; idle draws it in outline.
    static func menuBarImage(awake: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            draw(awake: awake)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = awake ? "Bee is keeping your Mac awake" : "Bee is idle"
        return image
    }

    private static func draw(awake: Bool) {
        NSColor.black.set()
        drawWings()
        drawHeadAndAntennae()
        let body = NSBezierPath(ovalIn: NSRect(x: 5.5, y: 2, width: 7, height: 10.5))
        let stripes = [NSRect(x: 4, y: 5, width: 10, height: 1.2), NSRect(x: 4, y: 8, width: 10, height: 1.2)]
        if awake {
            body.fill()
            withClip(body) { stripes.forEach { $0.fill(using: .clear) } }
        } else {
            body.lineWidth = 1.2
            body.stroke()
            withClip(body) { stripes.forEach { $0.fill() } }
        }
        let stinger = NSBezierPath()
        stinger.move(to: NSPoint(x: 8.2, y: 2.4))
        stinger.line(to: NSPoint(x: 9, y: 0.4))
        stinger.line(to: NSPoint(x: 9.8, y: 2.4))
        stinger.close()
        stinger.fill()
    }

    private static func drawWings() {
        for side in [-1.0, 1.0] {
            let wing = NSBezierPath(ovalIn: NSRect(x: -2.8, y: -1.7, width: 5.6, height: 3.4))
            var placement = AffineTransform(translationByX: 9 + side * 4.4, byY: 11.6)
            placement.rotate(byDegrees: side * 30)
            wing.transform(using: placement)
            wing.lineWidth = 1
            wing.stroke()
        }
    }

    private static func drawHeadAndAntennae() {
        NSBezierPath(ovalIn: NSRect(x: 7.3, y: 12.6, width: 3.4, height: 3.2)).fill()
        let antennae = NSBezierPath()
        antennae.move(to: NSPoint(x: 8.4, y: 15.4))
        antennae.line(to: NSPoint(x: 7, y: 17.4))
        antennae.move(to: NSPoint(x: 9.6, y: 15.4))
        antennae.line(to: NSPoint(x: 11, y: 17.4))
        antennae.lineWidth = 0.9
        antennae.lineCapStyle = .round
        antennae.stroke()
    }

    private static func withClip(_ path: NSBezierPath, _ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
}
