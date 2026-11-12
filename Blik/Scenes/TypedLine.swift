import SwiftUI

/// A line of text that types itself out with a human cadence, holds, then backspaces away.
/// Purely a function of `t`, the seconds since typing should begin.
struct TypedLine: View {
    let text: String
    let t: Double
    /// Local time at which backspacing starts; nil keeps the text on screen.
    var eraseAt: Double? = nil
    var font: Font
    var color: Color = .white
    var cursor: String = "_"

    static let eraseStep: Double = 0.045

    /// The moment each character lands, relative to the start of typing.
    static func typeTimes(_ chars: [Character]) -> [Double] {
        var times: [Double] = []
        var clock = 0.0
        for (index, char) in chars.enumerated() {
            if index > 0 {
                clock += 0.065 + 0.075 * rnd(index, chars.count)
                if char == "." || char == " " { clock += 0.07 }
            }
            times.append(clock)
        }
        return times
    }

    static func typingDuration(_ text: String) -> Double {
        typeTimes(Array(text)).last ?? 0
    }

    static func erasingDuration(_ text: String) -> Double {
        Double(text.count) * eraseStep
    }

    private struct Frame {
        var chars: [Character]
        var times: [Double]
        var shown: Int
        var cursorOn: Bool
    }

    private func frame() -> Frame {
        let chars = Array(text)
        let times = Self.typeTimes(chars)
        let count = chars.count

        var typed = 0
        for time in times where time <= t {
            typed += 1
        }

        var erased = 0
        if let eraseAt = eraseAt, t > eraseAt {
            erased = min(count, Int((t - eraseAt) / Self.eraseStep) + 1)
        }

        let typing = t >= 0 && typed < count
        let erasing = erased > 0 && erased < count
        let blinkOn = Int(abs(t) * 2.2) % 2 == 0
        return Frame(
            chars: chars,
            times: times,
            shown: max(0, min(typed, count - erased)),
            cursorOn: typing || erasing || blinkOn
        )
    }

    var body: some View {
        let state = frame()
        let count = state.chars.count
        HStack(spacing: 0) {
            ForEach(0...count, id: \.self) { index in
                ZStack {
                    if index < count {
                        let landed = index < state.shown
                        let settle = landed ? smooth((t - state.times[index]) / 0.11) : 0
                        Text(String(state.chars[index]))
                            .opacity(settle)
                            .offset(y: CGFloat((1 - settle) * 3))
                    } else {
                        // Reserves room for the cursor after the last character.
                        Text(cursor).opacity(0)
                    }
                    if index == state.shown {
                        Text(cursor).opacity(state.cursorOn ? 1 : 0)
                    }
                }
            }
        }
        .font(font)
        .foregroundColor(color)
        .fixedSize()
    }
}
