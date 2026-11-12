import AppKit

/// The two sounds of a focus session: a rising pair of notes when it starts,
/// the same pair falling when it ends. Synthesised, so there are no sound files to ship.
enum Chime {
    case on, off

    private static let low = 659.25   // E5
    private static let high = 987.77  // B5, a fifth above

    private static let sounds: [Chime: NSSound] = {
        var result: [Chime: NSSound] = [:]
        result[.on] = NSSound(data: wave(notes: [low, high]))
        result[.off] = NSSound(data: wave(notes: [high, low]))
        return result
    }()

    func play() {
        guard let sound = Self.sounds[self] else { return }
        sound.stop()
        sound.play()
    }

    static let sampleRate = 44_100.0
    /// Seconds between the two notes, and how long the whole chime rings.
    private static let spacing = 0.13
    private static let length = 1.1

    /// One sample of a soft mallet note `t` seconds after it is struck.
    private static func note(_ frequency: Double, _ t: Double) -> Double {
        guard t >= 0 else { return 0 }
        let turn = 2 * Double.pi * frequency * t
        let attack = 1 - exp(-t / 0.004)
        let body = sin(turn) * exp(-t / 0.28)
        let shimmer = 0.35 * sin(2 * turn) * exp(-t / 0.12) + 0.12 * sin(3 * turn) * exp(-t / 0.07)
        return attack * (body + shimmer)
    }

    /// The samples of a chime, in -1...1.
    static func samples(notes: [Double]) -> [Double] {
        let count = Int(length * sampleRate)
        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            var value = 0.0
            for (position, frequency) in notes.enumerated() {
                value += note(frequency, t - Double(position) * spacing)
            }
            // Fade the tail so the sound does not end on a click.
            let tail = min(1, (length - t) / 0.06)
            return value * 0.26 * tail
        }
    }

    /// A chime as a 16-bit mono WAV file in memory.
    static func wave(notes: [Double]) -> Data {
        let pcm = samples(notes: notes).map { Int16(max(-1, min(1, $0)) * 32_767) }
        let dataSize = UInt32(pcm.count * 2)
        let rate = UInt32(sampleRate)

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + dataSize)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))        // size of the format chunk
        append(UInt16(1))         // PCM
        append(UInt16(1))         // mono
        append(rate)
        append(rate * 2)          // bytes per second
        append(UInt16(2))         // bytes per frame
        append(UInt16(16))        // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        for sample in pcm {
            append(sample)
        }
        return data
    }
}
