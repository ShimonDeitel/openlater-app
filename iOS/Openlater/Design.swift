import SwiftUI

/// Keepsake identity: aged paper + ink + sealing wax. Warm, intimate, tactile — the
/// deliberate opposite of a cold utility app. The one vivid accent (wax red) is
/// reserved for seals, the unlock moment, and the Pro call-to-action.
enum OpenlaterColor {
    static let paper = Color(light: Color(hex: 0xF4ECDD), dark: Color(hex: 0x1C1712))
    static let paperPanel = Color(light: Color(hex: 0xEBDFC7), dark: Color(hex: 0x27201A))
    static let ink = Color(light: Color(hex: 0x2E241A), dark: Color(hex: 0xF0E6D6))
    static let inkMuted = Color(light: Color(hex: 0x7A6A54), dark: Color(hex: 0xB6A68E))
    static let hairline = Color(light: Color(hex: 0xD9C9A8), dark: Color(hex: 0x3B3025))

    /// Sealing wax. The signature accent — used for the seal, the "break" animation,
    /// and Pro.
    static let wax = Color(hex: 0xA8221B)
    static let waxDeep = Color(hex: 0x7A1712)
    static let waxHighlight = Color(hex: 0xD4584A)

    /// Gold leaf, used sparingly for embossed detail lines and the Pro badge.
    static let gold = Color(hex: 0xB98A34)
}

enum OpenlaterFont {
    static func serifTitle(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func serifHeadline(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat = 14) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// A soft, deckle-edged paper card — the primary chrome container across Openlater.
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OpenlaterColor.paperPanel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(OpenlaterColor.hairline, lineWidth: 1)
            )
    }
}

struct LetterButtonStyle: ButtonStyle {
    var filled: Bool = true
    var tint: Color = OpenlaterColor.wax

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OpenlaterFont.label(15))
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(filled ? tint : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint, lineWidth: filled ? 0 : 1.4)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func letterButton(filled: Bool = true, tint: Color = OpenlaterColor.wax) -> some View {
        buttonStyle(LetterButtonStyle(filled: filled, tint: tint))
    }

    /// Real tap-anywhere-to-dismiss-keyboard behavior for text-entry screens.
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
