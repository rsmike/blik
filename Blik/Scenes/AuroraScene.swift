import SwiftUI

/// Aurora theme: slow coloured light breathes in from the screen edges while the word drifts into focus.
struct AuroraScene: View {
    let kind: ReminderKind
    let message: String
    let dimmed: Bool
    let isPrimary: Bool
    let duration: Double

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let strength = envelope(t, 0, duration, fade: 0.9 * pace(duration))
            ZStack {
                AuroraBackdrop(t: t, strength: strength, veil: dimmed ? 0.42 : 0)
                if isPrimary {
                    content(t)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func content(_ t: Double) -> some View {
        let letters = kind.word.map { String($0) }
        let k = pace(duration)
        let glyphIn = envelope(t, 0.3 * k, duration - 0.7 * k, fade: 0.7 * k)
        let messageIn = envelope(t, 1.3 * k, duration - 0.9 * k, fade: 0.7 * k)
        return VStack(spacing: 20) {
            KindGlyph(kind: kind, t: t, color: .white, size: 66)
                .opacity(glyphIn)
                .scaleEffect(CGFloat(0.9 + 0.1 * glyphIn))
            HStack(spacing: 14) {
                ForEach(0..<letters.count, id: \.self) { index in
                    letter(letters[index], index: index, t: t)
                }
            }
            Text(verbatim: message)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.8))
                .opacity(messageIn)
        }
        .shadow(color: Color.black.opacity(0.45), radius: 14)
    }

    /// Each letter floats up into focus, then keeps rising as it blurs away.
    private func letter(_ value: String, index: Int, t: Double) -> some View {
        let k = pace(duration)
        let arrive = smooth((t - (0.5 + Double(index) * 0.07) * k) / (0.65 * k))
        let leave = smooth((t - duration + (1.5 - Double(index) * 0.045) * k) / (0.55 * k))
        let presence = arrive * (1 - leave)
        let offset = (1 - arrive) * 16 - leave * 16
        return Text(verbatim: value)
            .font(.system(size: 46, weight: .light, design: .rounded))
            .foregroundColor(.white)
            .opacity(presence)
            .blur(radius: CGFloat((1 - presence) * 10))
            .offset(y: CGFloat(offset))
    }
}

/// Rotating colour that glows inwards from the edges of the screen. No blur passes, so it stays cheap.
struct AuroraBackdrop: View {
    let t: Double
    let strength: Double
    let veil: Double

    private static let depth: CGFloat = 190
    private static let palette: [Color] = [
        Color(red: 0.20, green: 0.90, blue: 0.75),
        Color(red: 0.35, green: 0.55, blue: 1.00),
        Color(red: 0.65, green: 0.40, blue: 1.00),
        Color(red: 1.00, green: 0.45, blue: 0.70),
        Color(red: 0.20, green: 0.90, blue: 0.75)
    ]
    private static let falloff: [Color] = [
        Color.black,
        Color.black.opacity(0.45),
        Color.black.opacity(0.12),
        Color.clear
    ]

    var body: some View {
        let breath = 0.78 + 0.22 * sin(t * 1.5)
        ZStack {
            Color.black.opacity(veil * strength)
            AngularGradient(colors: Self.palette, center: .center, angle: .degrees(t * 32))
                .mask { edges }
                .opacity(strength * breath)
        }
    }

    private var edges: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(colors: Self.falloff, startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.depth)
                Spacer(minLength: 0)
                LinearGradient(colors: Self.falloff, startPoint: .bottom, endPoint: .top)
                    .frame(height: Self.depth)
            }
            HStack(spacing: 0) {
                LinearGradient(colors: Self.falloff, startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.depth)
                Spacer(minLength: 0)
                LinearGradient(colors: Self.falloff, startPoint: .trailing, endPoint: .leading)
                    .frame(width: Self.depth)
            }
        }
    }
}
