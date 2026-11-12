import SwiftUI

/// Almond eye outline. `openness` 1 is wide open, 0 is shut.
struct EyeShape: Shape {
    var openness: CGFloat

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let lift = rect.height * openness
        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: rect.midY - lift))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: rect.midY + lift))
        path.closeSubpath()
        return path
    }
}

/// A line-art eye that can blink.
struct EyeGlyph: View {
    var openness: CGFloat
    var color: Color
    var size: CGFloat = 40

    var body: some View {
        let height = size * 0.58
        let iris = height * 0.56
        let line = max(1.5, size * 0.055)
        ZStack {
            Circle()
                .fill(color)
                .frame(width: iris, height: iris)
                .frame(width: size, height: height)
                .clipShape(EyeShape(openness: openness))
            EyeShape(openness: openness)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: height)
        }
        .frame(width: size, height: height)
    }
}

/// Seated figure in profile. `slouch` 1 is hunched over, 0 is sitting tall.
struct PostureShape: Shape {
    var slouch: CGFloat

    var animatableData: CGFloat {
        get { slouch }
        set { slouch = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
            a + (b - a) * slouch
        }

        let hip = point(0.30, 0.70)
        let knee = point(0.70, 0.70)
        let foot = point(0.70, 0.98)
        let neck = point(mix(0.30, 0.52), mix(0.30, 0.40))
        let bend = point(mix(0.30, 0.14), 0.50)
        let radius = h * 0.11
        let head = CGPoint(x: neck.x + mix(0, 0.08) * w, y: neck.y - radius - h * 0.03)

        var path = Path()
        path.move(to: foot)
        path.addLine(to: knee)
        path.addLine(to: hip)
        path.addQuadCurve(to: neck, control: bend)
        path.addEllipse(in: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2))
        return path
    }
}

struct PostureGlyph: View {
    var slouch: CGFloat
    var color: Color
    var size: CGFloat = 40

    var body: some View {
        PostureShape(slouch: slouch)
            .stroke(color, style: StrokeStyle(lineWidth: max(1.5, size * 0.06), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// The animated icon for a reminder, driven by elapsed time.
struct KindGlyph: View {
    let kind: ReminderKind
    let t: Double
    var color: Color
    var size: CGFloat = 40

    var body: some View {
        switch kind {
        case .blink:
            EyeGlyph(openness: blinkOpenness(t), color: color, size: size)
        case .posture:
            PostureGlyph(slouch: postureSlouch(t), color: color, size: size)
        case .rest:
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.7, weight: .light))
                .foregroundColor(color)
        }
    }
}
