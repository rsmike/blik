import SwiftUI

/// Root view of one full-screen overlay window. Picks the scene for the reminder and theme.
/// Every screen gets the backdrop; only the primary screen (the one with the pointer) gets the content.
struct ReminderScene: View {
    let kind: ReminderKind
    let theme: Theme
    let dimmed: Bool
    let isPrimary: Bool
    let message: String

    var body: some View {
        Group {
            if kind == .rest {
                RestBreakView(theme: theme, dimmed: dimmed, isPrimary: isPrimary)
            } else {
                switch theme {
                case .keyboard:
                    KeyboardScene(kind: kind, dimmed: dimmed, isPrimary: isPrimary, duration: kind.duration)
                case .matrix:
                    MatrixScene(kind: kind, message: message, dimmed: dimmed, isPrimary: isPrimary, duration: kind.duration)
                case .aurora:
                    AuroraScene(kind: kind, message: message, dimmed: dimmed, isPrimary: isPrimary, duration: kind.duration)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The ambient layer of a theme: veil plus rain or glow. `strength` fades it in and out.
struct ThemeBackdrop: View {
    let theme: Theme
    let t: Double
    let strength: Double
    let veil: Double

    var body: some View {
        switch theme {
        case .keyboard:
            Color.black.opacity(veil * strength)
        case .matrix:
            MatrixBackdrop(t: t, strength: strength, veil: veil)
        case .aurora:
            AuroraBackdrop(t: t, strength: strength, veil: veil)
        }
    }
}
