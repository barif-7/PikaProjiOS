//
//  PikaDesignSystem.swift
//  PikaTakeHome
//
//  Updated to use the PikaDesignSystem name.
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

// MARK: - Static Style Types

/// Legacy font accessors kept for views that have not moved to `PikaDesignSystem`.
enum AppFont {
    static func telka(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black:
            return .custom("Telka Extended", size: size).weight(.black)
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
        case .black:
            return .custom("Telka", size: size).weight(.black)
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
        case .black:
            return .custom("Space Mono", size: size).weight(.black)
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

/// Legacy spacing tokens.
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
    static let fieldInset: CGFloat = 4
    static let fieldContentHorizontal: CGFloat = 14
    static let fieldLeadingInset: CGFloat = 16
    static let fieldTrailingInset: CGFloat = 10
    static let quoteInset: CGFloat = 39
    static let cameraChromeHorizontal: CGFloat = 18
    static let cameraControlsHorizontal: CGFloat = 34
    static let voiceScreenInset: CGFloat = 12
    static let successSectionGap: CGFloat = 24
}

/// Legacy corner‑radius tokens.
enum AppRadius {
    static let xs: CGFloat = 10
    static let sm: CGFloat = 16
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 36
    static let pill: CGFloat = 999
}

/// Shared control sizing tokens.
enum AppControlSize {
    static let topButton: CGFloat = 48
    static let closeButton: CGFloat = 44
    static let inputHeight: CGFloat = 48
    static let primaryButtonHeight: CGFloat = 56
    static let secondaryButtonHeight: CGFloat = 48
    static let iconButton: CGFloat = 64
    static let compactIconButton: CGFloat = 48
    static let voiceButton: CGFloat = 80
    static let voiceButtonInner: CGFloat = 64
}

enum AppShadow {
    static let softColor = Color.black.opacity(0.08)
    static let softRadius: CGFloat = 18
    static let softX: CGFloat = 0
    static let softY: CGFloat = 8
}

/// Legacy color palette and semantic aliases.
enum AppColor {
    // Raw palette from Figma MCP
    static let creamBase = Color(red: 253/255, green: 247/255, blue: 239/255)
    static let creamSurface = Color(red: 252/255, green: 250/255, blue: 247/255)
    static let inkPrimary = Color(red: 13/255, green: 13/255, blue: 13/255)
    static let inkSecondary = Color(red: 34/255, green: 34/255, blue: 34/255)
    static let lineDark = inkPrimary.opacity(0.25)
    static let washDark = inkPrimary.opacity(0.05)
    static let glassLight = Color.white.opacity(0.10)
    static let lavenderPrimary = Color(red: 207/255, green: 195/255, blue: 1.0)
    static let lavenderQuote = Color(red: 128/255, green: 110/255, blue: 202/255)
    static let successStroke = Color(red: 19/255, green: 17/255, blue: 14/255).opacity(0.12)
    static let successCardBottom = Color(red: 247/255, green: 244/255, blue: 235/255).opacity(0.5)

    // Semantic roles
    static let screenBackground = creamBase
    static let screenBackgroundElevated = creamBase
    static let surfacePrimary = creamSurface
    static let surfaceSecondary = creamSurface
    static let surfaceAccent = lavenderPrimary
    static let surfaceChrome = washDark
    static let surfaceField = washDark
    static let surfaceGlass = glassLight
    static let surfaceOverlay = creamSurface.opacity(0.9)
    static let surfaceSuccessCardTop = Color.white.opacity(0.5)
    static let surfaceSuccessCardBottom = successCardBottom

    static let textPrimary = inkPrimary
    static let textSecondary = inkSecondary.opacity(0.6)
    static let textTertiary = inkSecondary.opacity(0.5)
    static let textInverse = Color.white

    static let borderSubtle = lineDark
    static let accentPrimary = lavenderPrimary
    static let accentSecondary = lavenderPrimary
    static let accentMuted = lavenderPrimary
    static let accentQuote = lavenderQuote
    static let cameraBackground = Color.black
    static let successPrimaryButton = inkSecondary

    static let shadow = AppShadow.softColor
}

// MARK: - PikaDesignSystem Struct & EnvironmentKey

struct PikaDesignSystem {
    let colors: AppColor.Type
    let fonts: AppFont.Type
    let spacing: AppSpacing.Type
    let radius: AppRadius.Type
    let controlSize: AppControlSize.Type

    static let `default` = PikaDesignSystem(
        colors: AppColor.self,
        fonts: AppFont.self,
        spacing: AppSpacing.self,
        radius: AppRadius.self,
        controlSize: AppControlSize.self
    )
}

private struct PikaDesignSystemKey: EnvironmentKey {
    static let defaultValue: PikaDesignSystem = .default
}

extension EnvironmentValues {
    var designSystem: PikaDesignSystem {
        get { self[PikaDesignSystemKey.self] }
        set { self[PikaDesignSystemKey.self] = newValue }
    }
}

// MARK: - Compatibility Alias
// Keep the old name around so existing code continues to compile.
typealias DesignSystem = PikaDesignSystem

// MARK: - ViewModifiers (optional)

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
    func softShadow() -> some View { modifier(SoftShadow()) }
    func cardSurface() -> some View { modifier(CardSurfaceModifier()) }
}

// MARK: - Button Styles

/// Rounded primary button style used by the prototype onboarding flow.
struct PikaRoundedPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let textColor: Color?
    let backgroundColor: Color?
    let fontSize: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTextColor = textColor ?? AppColor.textPrimary
        let resolvedBackgroundColor = backgroundColor ?? AppColor.accentSecondary

        configuration.label
            .font(AppFont.telka(fontSize, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(isEnabled ? resolvedTextColor : resolvedTextColor.opacity(0.35))
            .background(isEnabled ? resolvedBackgroundColor : AppColor.accentMuted)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.99 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Rounded secondary button style used by the prototype onboarding flow.
struct PikaRoundedSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telka(15, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.secondaryButtonHeight)
            .foregroundStyle(AppColor.textPrimary)
            .background(AppColor.surfaceChrome)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColor.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Circular translucent button style for icon controls.
struct PikaGlassCircleButtonStyle: ButtonStyle {
    let diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(AppColor.surfaceChrome, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
