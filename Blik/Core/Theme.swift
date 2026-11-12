import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case keyboard, matrix, aurora

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .matrix: return "Matrix"
        case .aurora: return "Aurora"
        }
    }

    var accent: Color {
        switch self {
        case .keyboard: return .white
        case .matrix: return Color(red: 0.30, green: 1.0, blue: 0.45)
        case .aurora: return Color(red: 0.62, green: 0.84, blue: 1.0)
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .keyboard, .matrix: return .monospaced
        case .aurora: return .rounded
        }
    }

    /// Keyboard and Matrix type their captions out; Aurora fades them.
    var typesText: Bool { self != .aurora }

    /// Adapts a caption to the voice of the theme.
    func styled(_ text: String) -> String {
        switch self {
        case .keyboard: return text.lowercased()
        case .matrix: return "> " + text.lowercased()
        case .aurora: return text
        }
    }
}
