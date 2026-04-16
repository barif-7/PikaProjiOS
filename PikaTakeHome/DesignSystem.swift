import SwiftUI

enum AppFont {
    static func telka(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return .custom("Telka Extended", size: size).weight(.bold)
        case .semibold:
            return .custom("Telka Extended", size: size).weight(.semibold)
        case .medium:
            return .custom("Telka Extended", size: size).weight(.medium)
        case .light:
            return .custom("Telka Extended", size: size).weight(.light)
        default:
            return .custom("Telka Extended", size: size)
        }
    }

    static func telkaCompact(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return .custom("Telka", size: size).weight(.bold)
        case .semibold:
            return .custom("Telka", size: size).weight(.semibold)
        case .medium:
            return .custom("Telka", size: size).weight(.medium)
        case .light:
            return .custom("Telka", size: size).weight(.light)
        default:
            return .custom("Telka", size: size)
        }
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return .custom("Space Mono", size: size).weight(.bold)
        case .semibold:
            return .custom("Space Mono", size: size).weight(.semibold)
        case .medium:
            return .custom("Space Mono", size: size).weight(.medium)
        case .light:
            return .custom("Space Mono", size: size).weight(.light)
        default:
            return .custom("Space Mono", size: size)
        }
    }

    static func dots(_ size: CGFloat) -> Font {
        .custom("BPdotsVertical", size: size)
    }
}

enum AppSpacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 6
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let screenHorizontal: CGFloat = 24
    static let screenVertical: CGFloat = 24
}

enum AppRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let pill: CGFloat = 999
}

enum AppControlSize {
    static let inputHeight: CGFloat = 58
    static let primaryButtonHeight: CGFloat = 58
}

enum AppShadow {
    static let softColor = Color.black.opacity(0.08)
    static let softRadius: CGFloat = 18
    static let softX: CGFloat = 0
    static let softY: CGFloat = 8
}

enum AppColor {
    // Raw palette
    static let parchment = Color(red: 0.976, green: 0.965, blue: 0.939)
    static let parchment2 = Color(red: 0.988, green: 0.979, blue: 0.961)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.1)
    static let muted = Color(red: 0.53, green: 0.52, blue: 0.55)
    static let line = Color(red: 0.86, green: 0.84, blue: 0.82)
    static let lavender = Color(red: 0.78, green: 0.72, blue: 0.96)
    static let lavenderDeep = Color(red: 0.56, green: 0.43, blue: 0.97)
    static let lavenderSoft = Color(red: 0.92, green: 0.90, blue: 1.0)
    static let card = Color(red: 0.97, green: 0.95, blue: 0.92)

    // Semantic roles
    static let screenBackground = parchment
    static let screenBackgroundElevated = parchment2
    static let surfacePrimary = parchment2
    static let surfaceSecondary = card
    static let surfaceAccent = lavenderSoft

    static let textPrimary = ink
    static let textSecondary = muted
    static let textInverse = Color.white

    static let borderSubtle = line
    static let accentPrimary = lavenderDeep
    static let accentSecondary = lavender
    static let accentMuted = lavenderSoft
    static let cameraBackground = Color.black

    static let shadow = AppShadow.softColor
}

struct SoftShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: AppShadow.softColor,
            radius: AppShadow.softRadius,
            x: AppShadow.softX,
            y: AppShadow.softY
        )
    }
}

struct CardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.lg)
            .background(AppColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }
}

extension View {
    func softShadow() -> some View {
        modifier(SoftShadow())
    }

    func cardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }
}

struct PikaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telkaCompact(16, weight: .medium))
            .foregroundStyle(AppColor.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.accentPrimary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PikaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telkaCompact(16, weight: .medium))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.surfacePrimary)
            .overlay(
                Capsule()
                    .stroke(AppColor.borderSubtle, lineWidth: 1)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PikaRoundedPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telka(17, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.primaryButtonHeight)
            .foregroundStyle(isEnabled ? AppColor.textPrimary : AppColor.textPrimary.opacity(0.35))
            .background(isEnabled ? AppColor.accentSecondary : AppColor.accentMuted)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.99 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PikaRoundedSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telka(17, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.primaryButtonHeight)
            .foregroundStyle(AppColor.textPrimary)
            .background(Color.white.opacity(0.68))
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(AppColor.borderSubtle.opacity(0.8), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PikaGlassCircleButtonStyle: ButtonStyle {
    let diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(Color.white.opacity(0.56), in: Circle())
            .overlay(Circle().stroke(AppColor.borderSubtle.opacity(0.7), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
