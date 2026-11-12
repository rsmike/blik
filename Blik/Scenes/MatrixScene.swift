import SwiftUI

/// Matrix theme: digital rain falls over the whole screen while a terminal panel decodes the reminder.
struct MatrixScene: View {
    let kind: ReminderKind
    let message: String
    let dimmed: Bool
    let isPrimary: Bool
    let duration: Double

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let strength = envelope(t, 0, duration, fade: 0.7)
            ZStack {
                MatrixBackdrop(t: t, strength: strength, veil: dimmed ? 0.55 : 0)
                if isPrimary {
                    MatrixPanel(kind: kind, message: message, t: t, duration: duration, now: timeline.date)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct MatrixBackdrop: View {
    let t: Double
    let strength: Double
    let veil: Double

    var body: some View {
        ZStack {
            Color(red: 0, green: 0.04, blue: 0.015).opacity(veil * strength)
            MatrixRain(t: t).opacity(strength)
        }
    }
}

enum MatrixGlyphs {
    static let all: [String] = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789").map { String($0) }
}

/// Falling columns of glyphs. Stateless: every frame is computed from `t`.
struct MatrixRain: View {
    let t: Double

    var body: some View {
        // Everything the renderer needs is captured by value, so it is safe wherever SwiftUI runs it.
        let t = self.t
        let glyphs = MatrixGlyphs.all
        let columnWidth: CGFloat = 26
        let rowHeight: CGFloat = 19
        return Canvas { context, size in
            let font = Font.system(size: 15, weight: .medium, design: .monospaced)
            let tailColor = Theme.matrix.accent
            let headColor = Color(red: 0.86, green: 1.0, blue: 0.90)
            let tails = glyphs.map { context.resolve(Text($0).font(font).foregroundColor(tailColor)) }
            let heads = glyphs.map { context.resolve(Text($0).font(font).foregroundColor(headColor)) }

            let columns = Int(size.width / columnWidth) + 1
            let rows = Int(size.height / rowHeight) + 1
            // The rain enters from the top of the screen rather than appearing everywhere at once.
            let curtain = t * 70

            for column in 0..<columns {
                if rnd(column, 7) > 0.82 { continue }
                let speed = 6 + 10 * rnd(column, 1)
                let trail = 8 + Int(16 * rnd(column, 2))
                let span = Double(rows + trail + Int(30 * rnd(column, 4)))
                let head = (t * speed + rnd(column, 3) * span).truncatingRemainder(dividingBy: span)
                let headRow = Int(head)
                let x = (CGFloat(column) + 0.5) * columnWidth

                for step in 0...trail {
                    let row = headRow - step
                    if row < 0 || row >= rows || Double(row) > curtain { continue }
                    let shuffle = Int(t * 2 + rnd(column, row) * 7)
                    let pick = Int(rnd(column &* 131 &+ row, shuffle) * Double(glyphs.count)) % glyphs.count
                    let point = CGPoint(x: x, y: (CGFloat(row) + 0.5) * rowHeight)
                    if step == 0 {
                        context.opacity = 1
                        context.draw(heads[pick], at: point)
                    } else {
                        let distance = (head - Double(row)) / Double(trail + 1)
                        context.opacity = pow(max(0, 1 - distance), 1.5) * 0.8
                        context.draw(tails[pick], at: point)
                    }
                }
            }
        }
    }
}

/// Terminal panel: powers on like a CRT, decodes the word, types a hint, drains a timer, powers off.
struct MatrixPanel: View {
    let kind: ReminderKind
    let message: String
    let t: Double
    let duration: Double
    let now: Date

    private let green = Theme.matrix.accent
    private let bright = Color(red: 0.86, green: 1.0, blue: 0.90)
    private let barWidth: CGFloat = 426

    var body: some View {
        let power = smooth((t - 0.4) / 0.35) * smooth((duration - 0.5 - t) / 0.3)
        VStack(spacing: 0) {
            header
            Rectangle().fill(green.opacity(0.35)).frame(height: 1)
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 18) {
                    KindGlyph(kind: kind, t: t, color: green, size: 46)
                        .shadow(color: green.opacity(0.8), radius: 6)
                    word
                }
                hint
                timer
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .frame(width: 470)
        .background(Color.black.opacity(0.88))
        .overlay(Scanlines())
        .overlay(Rectangle().strokeBorder(green.opacity(0.7), lineWidth: 1))
        .shadow(color: green.opacity(0.45), radius: 16)
        .scaleEffect(x: CGFloat(0.7 + 0.3 * power), y: CGFloat(max(0.012, power)))
        .opacity(min(1, power * 5))
    }

    private var header: some View {
        HStack {
            Text(verbatim: "BLIK://" + kind.word)
            Spacer()
            Text(verbatim: now.formatted(date: .omitted, time: .standard))
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundColor(green.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var word: some View {
        let letters = kind.word.map { String($0) }
        return HStack(spacing: 5) {
            ForEach(0..<letters.count, id: \.self) { index in
                let locked = isLocked(index)
                Text(verbatim: locked ? letters[index] : scrambled(index))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(locked ? bright : green.opacity(0.7))
                    .shadow(color: green.opacity(locked ? 0.9 : 0), radius: 8)
                    .frame(width: 30)
            }
        }
    }

    /// Letters resolve left to right, then dissolve back into noise before the panel powers off.
    private func isLocked(_ index: Int) -> Bool {
        let lockAt = 0.95 + Double(index) * 0.12
        let unlockAt = duration - 1.3 + Double(index) * 0.05
        return t >= lockAt && t < unlockAt
    }

    private func scrambled(_ index: Int) -> String {
        let pool = MatrixGlyphs.all
        let pick = Int(rnd(index &+ 911, Int(t * 18)) * Double(pool.count)) % pool.count
        return pool[pick]
    }

    private var hint: some View {
        let full = "> " + message.lowercased()
        let count = max(0, min(full.count, Int((t - 1.7) * 34)))
        let cursorOn = Int(t * 2.5) % 2 == 0
        let typed = String(full.prefix(count)) + (cursorOn ? "█" : "")
        return Text(verbatim: full + "█")
            .opacity(0)
            .overlay(alignment: .leading) {
                Text(verbatim: typed).fixedSize()
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundColor(green)
    }

    private var timer: some View {
        let remaining = clamp01(1 - (t - 1.0) / max(0.1, duration - 2.4))
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(green.opacity(0.18))
                .frame(width: barWidth, height: 3)
            Rectangle()
                .fill(green)
                .frame(width: barWidth * CGFloat(remaining), height: 3)
                .shadow(color: green, radius: 4)
        }
    }
}

/// Faint CRT scanlines.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let line = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(line), with: .color(Color.black.opacity(0.28)))
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}
