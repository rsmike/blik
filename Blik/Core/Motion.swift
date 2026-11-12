import CoreGraphics
import Foundation

// Every animation in Blik is a pure function of elapsed time, built from these helpers.

func clamp01(_ x: Double) -> Double {
    min(1, max(0, x))
}

/// Smoothstep: eases 0...1 in and out.
func smooth(_ x: Double) -> Double {
    let c = clamp01(x)
    return c * c * (3 - 2 * c)
}

/// Rises 0 -> 1 over `fade` seconds after `start`, falls 1 -> 0 over `fade` seconds before `end`.
func envelope(_ t: Double, _ start: Double, _ end: Double, fade: Double = 0.6) -> Double {
    smooth((t - start) / fade) * smooth((end - t) / fade)
}

/// Time scale for a reminder's choreography. Scenes are composed for 5 seconds or more;
/// a shorter reminder plays the same moves compressed evenly.
func pace(_ duration: Double) -> Double {
    min(1, duration / 5)
}

/// Deterministic pseudo-random value in 0..<1 for a pair of integers.
func rnd(_ a: Int, _ b: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: a) &* 0x9E37_79B9_7F4A_7C15
    x ^= UInt64(truncatingIfNeeded: b) &* 0xC2B2_AE3D_27D4_EB4F
    x ^= x >> 33
    x = x &* 0xFF51_AFD7_ED55_8CCD
    x ^= x >> 33
    x = x &* 0xC4CE_B9FE_1A85_EC53
    x ^= x >> 33
    return Double(x % 100_000) / 100_000
}

/// Eye openness (1 open, ~0 closed) for an eye that blinks once per `period`.
func blinkOpenness(_ t: Double, period: Double = 1.9) -> CGFloat {
    let phase = t.truncatingRemainder(dividingBy: period)
    let length = 0.22
    guard phase >= 0, phase < length else { return 1 }
    let half = length / 2
    return CGFloat(max(0.06, abs(phase - half) / half))
}

/// Slouch amount (1 slouched, 0 upright) for a figure that keeps straightening up.
func postureSlouch(_ t: Double) -> CGFloat {
    let phase = t.truncatingRemainder(dividingBy: 3.4)
    if phase < 0.8 { return 1 }
    if phase < 1.3 { return CGFloat(1 - smooth((phase - 0.8) / 0.5)) }
    if phase < 2.8 { return 0 }
    return CGFloat(smooth((phase - 2.8) / 0.6))
}
