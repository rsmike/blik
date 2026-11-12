import SwiftUI

/// The long break: look away, eye gymnastics (follow the dot), then a glass of water.
/// Styled by the active theme; timing lives in `RestTimeline`.
struct RestBreakView: View {
    let theme: Theme
    let dimmed: Bool
    let isPrimary: Bool

    @State private var start = Date()

    private let total = RestTimeline.total
    private var accent: Color { theme.accent }

    var body: some View {
        ZStack {
            // The backdrop runs at 30 fps; the content (and the dot you follow) at full frame rate.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                // Matrix rain is turned down so it does not fight the exercise for attention.
                let gain = theme == .matrix ? 0.5 : 1.0
                ThemeBackdrop(
                    theme: theme,
                    t: t,
                    strength: envelope(t, 0, total, fade: 0.9) * gain,
                    veil: (dimmed ? 0.8 : 0) / gain
                )
            }
            if isPrimary {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSince(start)
                    GeometryReader { proxy in
                        stage(t: t, size: proxy.size)
                    }
                    .opacity(envelope(t, 0, total, fade: 0.9))
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Stage

    @ViewBuilder
    private func stage(t: Double, size: CGSize) -> some View {
        let lookEnd = RestTimeline.lookAway
        let gymEnd = lookEnd + RestTimeline.gymnastics
        ZStack {
            if !dimmed {
                // Without the dim there is still a soft pool of shade so the text stays readable.
                RadialGradient(
                    colors: [Color.black.opacity(0.55), Color.clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 440
                )
            }
            if t < lookEnd {
                lookAway(u: t)
                    .opacity(envelope(t, 0, lookEnd))
            } else if t < gymEnd {
                gymnastics(u: t - lookEnd, size: size)
                    .opacity(envelope(t, lookEnd, gymEnd))
            } else {
                drink(u: t - gymEnd)
                    .opacity(smooth((t - gymEnd) / 0.6))
            }
            progress(t: t)
                .position(x: size.width / 2, y: size.height * 0.08)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Look away

    private func lookAway(u: Double) -> some View {
        let length = RestTimeline.lookAway
        let remaining = max(0, length - u)
        return VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(clamp01(remaining / length)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: String(Int(remaining.rounded(.up))))
                    .font(.system(size: 46, weight: .light, design: theme.fontDesign))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .frame(width: 150, height: 150)
            caption("Look at something far away", local: u - 0.8, length: length - 0.8, size: 24)
        }
    }

    // MARK: - Eye gymnastics

    private struct GymStep {
        var text: String
        var start: Double
        var length: Double
    }

    private static func gymStep(_ u: Double) -> GymStep {
        if u < 3 { return GymStep(text: "Follow the dot", start: 0, length: 3) }
        if u < 11 { return GymStep(text: "Left, right", start: 3, length: 8) }
        if u < 19 { return GymStep(text: "Up, down", start: 11, length: 8) }
        return GymStep(text: "Circles", start: 19, length: 7)
    }

    private func gymnastics(u: Double, size: CGSize) -> some View {
        let ax = Double(size.width) * 0.40
        let ay = Double(size.height) * 0.30
        let step = Self.gymStep(u)
        let head = RestTimeline.dotOffset(u, ax: ax, ay: ay)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let tint = accent
        return ZStack {
            Canvas { context, canvasSize in
                let origin = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for index in stride(from: 16, through: 1, by: -1) {
                    let past = RestTimeline.dotOffset(u - Double(index) * 0.018, ax: ax, ay: ay)
                    let life = 1 - Double(index) / 17
                    let radius = CGFloat(3 + 6 * life)
                    let rect = CGRect(
                        x: origin.x + past.x - radius,
                        y: origin.y + past.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.08 + 0.4 * life * life)))
                }
            }
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .shadow(color: tint, radius: 10)
                .shadow(color: tint.opacity(0.6), radius: 24)
                .scaleEffect(CGFloat(u < 3 ? 1 + 0.25 * sin(u * 5) : 1))
                .position(x: centre.x + head.x, y: centre.y + head.y)
                .opacity(smooth((u - 0.3) / 0.6))
            caption(step.text, local: u - step.start, length: step.length, size: 22)
                .position(x: centre.x, y: size.height * 0.15)
        }
    }

    // MARK: - Drink

    private func drink(u: Double) -> some View {
        VStack(spacing: 30) {
            WaterGlass(t: u, color: accent)
            caption("Drink some water", local: u - 0.5, length: RestTimeline.drink - 0.9, size: 24)
        }
    }

    // MARK: - Shared pieces

    @ViewBuilder
    private func caption(_ text: String, local: Double, length: Double, size: CGFloat) -> some View {
        let styled = theme.styled(text)
        let font = Font.system(size: size, weight: theme == .aurora ? .regular : .medium, design: theme.fontDesign)
        if theme.typesText {
            TypedLine(
                text: styled,
                t: local,
                eraseAt: length - TypedLine.erasingDuration(styled) - 0.35,
                font: font,
                color: theme == .matrix ? accent : .white,
                cursor: theme == .matrix ? "█" : "_"
            )
            .shadow(color: Color.black.opacity(0.5), radius: 10)
        } else {
            Text(verbatim: styled)
                .font(font)
                .foregroundColor(.white)
                .opacity(envelope(local, 0, length, fade: 0.7))
                .shadow(color: Color.black.opacity(0.5), radius: 10)
        }
    }

    private func progress(t: Double) -> some View {
        let first = RestTimeline.lookAway
        let second = first + RestTimeline.gymnastics
        let starts: [Double] = [0, first, second]
        let ends: [Double] = [first, second, total]
        let tint = accent
        return HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                let filled = clamp01((t - starts[index]) / (ends[index] - starts[index]))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 54, height: 3)
                    Capsule()
                        .fill(tint)
                        .frame(width: 54 * CGFloat(filled), height: 3)
                }
            }
        }
    }
}

/// Lives in its own small window, the only part of a break that takes clicks.
struct SkipButton: View {
    let theme: Theme
    let action: () -> Void

    @State private var hovering = false
    @State private var visible = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: theme == .aurora ? "Skip" : "skip")
                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                .foregroundColor(Color.white.opacity(hovering ? 1 : 0.7))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(hovering ? 0.24 : 0.12)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .opacity(visible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
                visible = true
            }
        }
    }
}
