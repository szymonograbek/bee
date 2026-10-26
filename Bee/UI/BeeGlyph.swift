import AppKit

/// The menu bar icon: the app icon's round cartoon bee, facing left, drawn in code so it stays crisp at any scale.
enum BeeGlyph {
    /// Both states share one size so the menu bar item never changes width.
    private static let size = NSSize(width: 22, height: 18)

    /// A template image, so the menu bar tints it for light, dark, and highlighted states.
    /// Awake draws the bee in flight with lightning bolts for eyes; idle draws it asleep under a trail of z's.
    static func menuBarImage(awake: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            if awake {
                withTransform(translate: NSPoint(x: 10.8, y: 7.2), rotate: -14, scale: 0.92) {
                    drawBee(awake: true)
                }
            } else {
                withTransform(translate: NSPoint(x: 13, y: 6.8), rotate: 8, scale: 0.82) {
                    drawBee(awake: false)
                }
                drawZ(at: NSPoint(x: 4, y: 6.8), size: 1.8)
                drawZ(at: NSPoint(x: 1.8, y: 9.8), size: 2.2)
                drawZ(at: NSPoint(x: 0.4, y: 13.4), size: 2.6)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = awake ? "Bee is keeping your Mac awake" : "Bee is idle"
        return image
    }

    /// Draws a bee facing left with its body centred on the origin, about 17 points wide and 15 tall.
    /// Awake, the bee is solid, its wings are raised, and its eyes are lightning bolts cut out of the body;
    /// asleep, it is drawn in outline with folded wings and shut eyes.
    private static func drawBee(awake: Bool) {
        drawWings(raised: awake)
        drawAntennae()
        let body = bodyPath()
        // A thin gap keeps the body from melting into the wings and antennae behind it.
        body.lineWidth = 1.6
        erasing { body.stroke() }
        if awake {
            body.fill()
            withClip(body) {
                erasing { drawMarkings(awake: true) }
            }
        } else {
            erasing { body.fill() }
            body.lineWidth = 1.2
            body.stroke()
            withClip(body) { drawMarkings(awake: false) }
        }
    }

    /// A plump teardrop: round at the head, tapering smoothly into the stinger.
    private static func bodyPath() -> NSBezierPath {
        let tip = NSPoint(x: 9, y: -0.8)
        // Each segment runs anticlockwise from the stinger: over the back, round the face, and under the belly.
        let segments = [
            CurveSegment(
                to: NSPoint(x: 0, y: 5.2),
                control1: NSPoint(x: 6.4, y: 1.6),
                control2: NSPoint(x: 4.4, y: 5.2)
            ),
            CurveSegment(
                to: NSPoint(x: -7.4, y: 0),
                control1: NSPoint(x: -4.2, y: 5.2),
                control2: NSPoint(x: -7.4, y: 3)
            ),
            CurveSegment(
                to: NSPoint(x: 0, y: -5.2),
                control1: NSPoint(x: -7.4, y: -3),
                control2: NSPoint(x: -4.2, y: -5.2)
            ),
            CurveSegment(
                to: tip,
                control1: NSPoint(x: 4.4, y: -5.2),
                control2: NSPoint(x: 6.4, y: -2.8)
            )
        ]
        let body = NSBezierPath()
        body.move(to: tip)
        for segment in segments {
            body.curve(to: segment.to, controlPoint1: segment.control1, controlPoint2: segment.control2)
        }
        body.close()
        body.lineJoinStyle = .round
        return body
    }

    /// Stripes across the back half and the face on the front; the caller decides whether they paint or cut.
    private static func drawMarkings(awake: Bool) {
        NSRect(x: 0.6, y: -6, width: 1.2, height: 12).fill()
        NSRect(x: 3.6, y: -6, width: 1.2, height: 12).fill()
        if awake {
            drawBolt(centeredAt: NSPoint(x: -5, y: 1.6))
            drawBolt(centeredAt: NSPoint(x: -2, y: 1.6))
        } else {
            drawClosedEye(centeredAt: NSPoint(x: -5, y: 1.2))
            drawClosedEye(centeredAt: NSPoint(x: -2, y: 1.2))
        }
        drawSmile()
    }

    private static func drawWings(raised: Bool) {
        // The far wing sits behind and leans back further than the near one.
        let wings = raised
            ? [
                Wing(center: NSPoint(x: 6.8, y: 5.4), width: 4.8, height: 6.4, tilt: -55),
                Wing(center: NSPoint(x: 3.8, y: 6.6), width: 5.6, height: 7.4, tilt: -30)
            ]
            : [
                Wing(center: NSPoint(x: 6.6, y: 3.6), width: 4.2, height: 6.4, tilt: -78),
                Wing(center: NSPoint(x: 4, y: 4.6), width: 4.8, height: 7.2, tilt: -66)
            ]
        for wing in wings {
            let frame = NSRect(x: -wing.width / 2, y: -wing.height / 2, width: wing.width, height: wing.height)
            let path = NSBezierPath(ovalIn: frame)
            var placement = AffineTransform(translationByX: wing.center.x, byY: wing.center.y)
            placement.rotate(byDegrees: wing.tilt)
            path.transform(using: placement)
            erasing { path.fill() }
            path.lineWidth = 1.1
            path.stroke()
        }
    }

    private static func drawAntennae() {
        let stalks = [
            Antenna(start: NSPoint(x: -4.8, y: 3.4), control: NSPoint(x: -5.6, y: 6.6), tip: NSPoint(x: -8, y: 7.4)),
            Antenna(start: NSPoint(x: -1.8, y: 4.6), control: NSPoint(x: -2, y: 8.2), tip: NSPoint(x: -4.4, y: 9.6))
        ]
        for stalk in stalks {
            let path = NSBezierPath()
            path.move(to: stalk.start)
            path.curve(to: stalk.tip, controlPoint1: stalk.control, controlPoint2: stalk.control)
            path.lineWidth = 1
            path.lineCapStyle = .round
            path.stroke()
            NSBezierPath(ovalIn: NSRect(x: stalk.tip.x - 1, y: stalk.tip.y - 1, width: 2, height: 2)).fill()
        }
    }

    /// A lightning bolt about 2 points wide and 3.6 tall.
    private static func drawBolt(centeredAt center: NSPoint) {
        let points: [(CGFloat, CGFloat)] = [
            (0.2, 1.8), (-1, -0.1), (-0.1, -0.1), (-0.5, -1.8), (1, 0.4), (0.1, 0.4), (0.8, 1.8)
        ]
        let bolt = NSBezierPath()
        for (index, point) in points.enumerated() {
            let location = NSPoint(x: center.x + point.0, y: center.y + point.1)
            if index == 0 {
                bolt.move(to: location)
            } else {
                bolt.line(to: location)
            }
        }
        bolt.close()
        bolt.fill()
    }

    /// A sleepy downward arc.
    private static func drawClosedEye(centeredAt center: NSPoint) {
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: center.x - 1.1, y: center.y + 0.4))
        eye.curve(
            to: NSPoint(x: center.x + 1.1, y: center.y + 0.4),
            controlPoint1: NSPoint(x: center.x - 0.7, y: center.y - 0.7),
            controlPoint2: NSPoint(x: center.x + 0.7, y: center.y - 0.7)
        )
        eye.lineWidth = 0.9
        eye.lineCapStyle = .round
        eye.stroke()
    }

    private static func drawSmile() {
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: -4.6, y: -1.6))
        smile.curve(
            to: NSPoint(x: -2.8, y: -1.6),
            controlPoint1: NSPoint(x: -4.3, y: -2.6),
            controlPoint2: NSPoint(x: -3.1, y: -2.6)
        )
        smile.lineWidth = 0.9
        smile.lineCapStyle = .round
        smile.stroke()
    }

    private static func drawZ(at origin: NSPoint, size: CGFloat) {
        let letter = NSBezierPath()
        letter.move(to: NSPoint(x: origin.x, y: origin.y + size))
        letter.line(to: NSPoint(x: origin.x + size, y: origin.y + size))
        letter.line(to: NSPoint(x: origin.x, y: origin.y))
        letter.line(to: NSPoint(x: origin.x + size, y: origin.y))
        letter.lineWidth = 0.9
        letter.lineJoinStyle = .round
        letter.lineCapStyle = .round
        letter.stroke()
    }

    private static func withTransform(
        translate offset: NSPoint,
        rotate degrees: CGFloat,
        scale: CGFloat,
        _ draw: () -> Void
    ) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: offset.x, yBy: offset.y)
        transform.rotate(byDegrees: degrees)
        transform.scale(by: scale)
        transform.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Runs `draw` with every mark cutting a transparent hole instead of painting.
    private static func erasing(_ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func withClip(_ path: NSBezierPath, _ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
}

private struct CurveSegment {
    let to: NSPoint
    let control1: NSPoint
    let control2: NSPoint
}

private struct Wing {
    let center: NSPoint
    let width: CGFloat
    let height: CGFloat
    let tilt: CGFloat
}

private struct Antenna {
    let start: NSPoint
    let control: NSPoint
    let tip: NSPoint
}
