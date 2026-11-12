import AppKit
import SwiftUI

/// Where reminders drop from on a display: its notch, or a stand-in on the top edge if it has none.
struct NotchAnchor {
    /// In the overlay's coordinates: origin at the top-left corner of the display.
    var rect: CGRect

    init(rect: CGRect) {
        self.rect = rect
    }

    init(screen: NSScreen) {
        let frame = screen.frame
        let inset = screen.safeAreaInsets.top
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            rect = CGRect(x: left.width, y: 0, width: frame.width - left.width - right.width, height: inset)
        } else {
            // No notch: drops come out of the top edge instead.
            rect = CGRect(x: frame.width / 2 - 90, y: 0, width: 180, height: 0)
        }
    }

    static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }
}

/// One piece of liquid: a rounded rectangle, or a circle when the radius is half its side.
struct LiquidBlob {
    var rect: CGRect
    var radius: CGFloat

    static func circle(x: CGFloat, y: CGFloat, r: CGFloat) -> LiquidBlob {
        LiquidBlob(rect: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), radius: r)
    }
}

/// Draws blobs as one body of black liquid. Blurring them together and cutting the result off at
/// half strength makes neighbours bridge, stretch and pinch apart the way drops do.
struct LiquidLayer: View {
    let blobs: [LiquidBlob]

    var body: some View {
        let blobs = self.blobs
        Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: 5))
            context.drawLayer { layer in
                for blob in blobs where blob.rect.width > 0 && blob.rect.height > 0 {
                    let radius = min(blob.radius, blob.rect.width / 2, blob.rect.height / 2)
                    layer.fill(Path(roundedRect: blob.rect, cornerRadius: radius), with: .color(.black))
                }
            }
        }
        // A hairline of light keeps the liquid readable over dark windows.
        .shadow(color: Color.white.opacity(0.28), radius: 0.7)
        .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)
        .allowsHitTesting(false)
    }
}

/// The shapes a drop goes through. Pure geometry, in the coordinates of the canvas it is drawn in:
/// `midX` is the centre of the notch and y runs down from the top of the display.
enum NotchDrop {
    static let radius: CGFloat = 11
    /// Space between the notch and the pill a toast settles into.
    static let pillGap: CGFloat = 30

    // Seconds. The same for every reminder.
    static let hangs = 0.3
    static let falls = 0.38
    static let spreads = 0.45
    /// From nothing to an open pill, and the same again on the way back.
    static let lead = hangs + falls + spreads

    /// Damped spring from 0 to 1 that overshoots once.
    static func spring(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return 1 - exp(-6 * x) * cos(10 * x)
    }

    /// The notch itself, so liquid leaving it stretches from its lower edge.
    static func source(notch: CGSize, midX: CGFloat) -> LiquidBlob {
        LiquidBlob(
            rect: CGRect(x: midX - notch.width / 2 + 1, y: -40, width: notch.width - 2, height: 39 + notch.height),
            radius: 9
        )
    }

    /// The thread between the notch and a drop at `y`; it thins as the drop falls and then snaps.
    static func neck(midX: CGFloat, from top: CGFloat, to y: CGFloat, fall: Double) -> [LiquidBlob] {
        let thin = 1 - fall / 0.75
        guard fall > 0, thin > 0 else { return [] }
        return [0.2, 0.45, 0.7].map { along in
            .circle(x: midX, y: top + (y - top) * CGFloat(along), r: radius * CGFloat(0.6 * thin * (0.6 + 0.4 * along)))
        }
    }

    struct Toast {
        var blobs: [LiquidBlob]
        var centreY: CGFloat
        /// Opacity of whatever the pill carries.
        var content: Double
    }

    /// A drop that hangs from the notch, falls, and spreads into a pill.
    /// `m` is the time to the nearest end of the reminder, so the exit is the entrance played backwards.
    static func toast(m: Double, springy: Bool, notch: CGSize, pill: CGSize, midX: CGFloat) -> Toast {
        let r = radius
        let restY = notch.height + pillGap + pill.height / 2
        guard m > 0 else {
            return Toast(blobs: [], centreY: restY, content: 0)
        }
        let hang = smooth(m / hangs)
        let fall = clamp01((m - hangs) / falls)
        let spread = (m - hangs - falls) / spreads

        let hangY = notch.height - r + CGFloat(hang) * r * 1.5
        let y = hangY + (restY - hangY) * CGFloat(fall * fall)
        let wide = springy ? spring(spread) : smooth(spread)
        let tall = smooth(spread * 1.4)
        let width = 2 * r + (pill.width - 2 * r) * CGFloat(wide)
        let height = 2 * r + (pill.height - 2 * r) * CGFloat(tall)

        var blobs = [source(notch: notch, midX: midX)]
        blobs += neck(midX: midX, from: notch.height, to: y, fall: fall)
        blobs.append(LiquidBlob(
            rect: CGRect(x: midX - width / 2, y: y - height / 2, width: width, height: height),
            radius: height / 2
        ))
        // Whatever the pill carries shows up as it finishes opening.
        return Toast(blobs: blobs, centreY: y, content: smooth((m - lead + 0.2) / 0.2))
    }

    /// A teardrop that hangs from the notch and falls all the way to `landing`.
    static func plunge(t: Double, lands: Double, notch: CGSize, landing: CGFloat, midX: CGFloat) -> [LiquidBlob] {
        let r = radius
        let hang = smooth(t / hangs)
        let fall = clamp01((t - hangs) / (lands - hangs))
        let hangY = notch.height - r + CGFloat(hang) * r * 1.5
        let y = hangY + (landing - hangY) * CGFloat(fall * fall)
        // The faster it falls, the longer the tail it trails.
        let stretch = CGFloat(min(1, fall * 3))
        var blobs = [source(notch: notch, midX: midX)]
        blobs += neck(midX: midX, from: notch.height, to: min(y, notch.height + 60), fall: min(1, fall * 4))
        blobs.append(.circle(x: midX, y: y - r * 2.4 * stretch, r: r * 0.4))
        blobs.append(.circle(x: midX, y: y - r * 1.6 * stretch, r: r * 0.6))
        blobs.append(.circle(x: midX, y: y - r * 0.8 * stretch, r: r * 0.8))
        blobs.append(.circle(x: midX, y: y, r: r))
        return blobs
    }
}

/// The dim that goes with a reminder toast. It covers every display, because the toast itself
/// plays on one. It shares the toast's two ends but is quicker than the drop: it comes down as
/// the drop starts to appear, so it is in place before the pill has opened, and it lifts late,
/// reaching nothing just as the drop is gone.
struct ToastDim: View {
    /// How long the toast it accompanies stays on screen.
    let duration: Double

    @State private var start = Date()

    static let strength = 0.5
    /// Seconds the dim takes to come down, and to lift.
    static let fade = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Color.black.opacity(Self.strength * envelope(t, 0, duration, fade: Self.fade))
        }
        .ignoresSafeArea()
    }
}

/// A toast: a drop of black liquid falls out of the notch and spreads into a small pill
/// that types a word, then gathers itself and goes back up.
struct NotchScene: View {
    let spec: ToastSpec
    let anchor: NotchAnchor

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            NotchToast(spec: spec, anchor: anchor, t: timeline.date.timeIntervalSince(start))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// One frame of the toast, `t` seconds in.
struct NotchToast: View {
    let spec: ToastSpec
    let anchor: NotchAnchor
    let t: Double

    private static let fontSize: CGFloat = 15
    private static let glyphSize: CGFloat = 22
    private static let padding: CGFloat = 17
    private static let spacing: CGFloat = 9

    private var text: String { spec.text }
    private var duration: Double { spec.duration }

    @ViewBuilder
    private var icon: some View {
        switch spec.icon {
        case .glyph(let kind):
            KindGlyph(kind: kind, t: t, color: .white, size: Self.glyphSize)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var pill: CGSize {
        // Monospaced: every character, and the cursor after them, is 0.6 em wide.
        let textWidth = CGFloat(text.count + 1) * Self.fontSize * 0.61
        return CGSize(width: Self.padding * 2 + Self.glyphSize + Self.spacing + textWidth, height: 38)
    }

    var body: some View {
        let pill = self.pill
        let canvas = CGSize(
            width: max(pill.width * 1.25, anchor.rect.width) + 80,
            height: anchor.rect.height + NotchDrop.pillGap + pill.height + 50
        )
        let toast = NotchDrop.toast(
            m: min(t, duration - t),
            springy: t < duration / 2,
            notch: anchor.rect.size,
            pill: pill,
            midX: canvas.width / 2
        )
        ZStack {
            Color.clear
            LiquidLayer(blobs: toast.blobs)
                .frame(width: canvas.width, height: canvas.height)
                .position(x: anchor.rect.midX, y: canvas.height / 2)
            HStack(spacing: Self.spacing) {
                icon
                    .frame(width: Self.glyphSize, height: Self.glyphSize)
                // Typing starts once the pill is open and is backspaced before it closes.
                TypedLine(
                    text: text,
                    t: t - NotchDrop.lead,
                    eraseAt: spec.eraseAt,
                    font: .system(size: Self.fontSize, weight: .medium, design: .monospaced)
                )
            }
            .opacity(toast.content)
            .position(x: anchor.rect.midX, y: toast.centreY)
        }
    }
}

/// How a rest break opens: the drop falls to the middle of the display
/// and spreads until it has become the dim. Other displays simply dim along with it.
struct NotchRestBackdrop: View {
    let anchor: NotchAnchor
    let isPrimary: Bool
    let t: Double
    let veil: Double

    /// The moment the drop reaches the middle of the display, and the moment it has covered it.
    static let lands = 0.95
    static let covers = 1.75

    var body: some View {
        let spread = clamp01((t - Self.lands) / (Self.covers - Self.lands))
        if !isPrimary || spread >= 1 {
            Color.black.opacity(veil * smooth(spread))
        } else {
            GeometryReader { proxy in
                let size = proxy.size
                let centre = CGPoint(x: anchor.rect.midX, y: size.height / 2)
                if t < Self.lands {
                    let width: CGFloat = 140
                    let height = centre.y + 40
                    LiquidLayer(blobs: NotchDrop.plunge(
                        t: t,
                        lands: Self.lands,
                        notch: anchor.rect.size,
                        landing: centre.y,
                        midX: width / 2
                    ))
                    .frame(width: width, height: height)
                    .position(x: centre.x, y: height / 2)
                } else {
                    // With the dim switched off the drop just soaks away into the shade behind the text.
                    let reach = veil > 0 ? hypot(max(centre.x, size.width - centre.x), centre.y) + 20 : 440
                    let eased = 1 - pow(1 - spread, 3)
                    let radius = NotchDrop.radius + (reach - NotchDrop.radius) * CGFloat(eased)
                    Circle()
                        .fill(Color.black.opacity(1 + (veil - 1) * smooth(spread * 1.6)))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(centre)
                }
            }
        }
    }
}
