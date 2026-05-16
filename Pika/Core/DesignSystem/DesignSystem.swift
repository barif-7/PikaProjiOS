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

// MARK: - Base44 "Semi" Design Tokens

struct SemiTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundTop: Color
    let backgroundBottom: Color
    let accent: Color
    let aura: [Color]
    let listenColor: Color
    let speakColor: Color
    let unlocksAt: Int

    static let midnight = SemiTheme(
        id: "midnight",
        name: "Midnight",
        backgroundTop: Color(red: 12/255, green: 12/255, blue: 16/255),
        backgroundBottom: Color(red: 22/255, green: 20/255, blue: 31/255),
        accent: Color(red: 123/255, green: 94/255, blue: 246/255),
        aura: [
            Color(red: 123/255, green: 94/255, blue: 246/255),
            Color(red: 74/255, green: 46/255, blue: 158/255),
            Color(red: 26/255, green: 10/255, blue: 61/255)
        ],
        listenColor: Color(red: 91/255, green: 141/255, blue: 239/255),
        speakColor: Color(red: 240/255, green: 153/255, blue: 123/255),
        unlocksAt: 0
    )

    static let aurora = SemiTheme(
        id: "aurora",
        name: "Aurora",
        backgroundTop: Color(red: 4/255, green: 52/255, blue: 44/255),
        backgroundBottom: Color(red: 15/255, green: 31/255, blue: 28/255),
        accent: Color(red: 29/255, green: 158/255, blue: 117/255),
        aura: [
            Color(red: 29/255, green: 158/255, blue: 117/255),
            Color(red: 8/255, green: 80/255, blue: 65/255),
            Color(red: 4/255, green: 52/255, blue: 44/255)
        ],
        listenColor: Color(red: 59/255, green: 184/255, blue: 154/255),
        speakColor: Color(red: 125/255, green: 217/255, blue: 168/255),
        unlocksAt: 25
    )

    static let ember = SemiTheme(
        id: "ember",
        name: "Ember",
        backgroundTop: Color(red: 26/255, green: 10/255, blue: 4/255),
        backgroundBottom: Color(red: 31/255, green: 16/255, blue: 8/255),
        accent: Color(red: 216/255, green: 90/255, blue: 48/255),
        aura: [
            Color(red: 240/255, green: 153/255, blue: 123/255),
            Color(red: 216/255, green: 90/255, blue: 48/255),
            Color(red: 74/255, green: 27/255, blue: 12/255)
        ],
        listenColor: Color(red: 232/255, green: 168/255, blue: 124/255),
        speakColor: Color(red: 240/255, green: 192/255, blue: 96/255),
        unlocksAt: 50
    )

    static let sakura = SemiTheme(
        id: "sakura",
        name: "Sakura",
        backgroundTop: Color(red: 26/255, green: 8/255, blue: 16/255),
        backgroundBottom: Color(red: 32/255, green: 12/255, blue: 24/255),
        accent: Color(red: 212/255, green: 83/255, blue: 126/255),
        aura: [
            Color(red: 237/255, green: 147/255, blue: 177/255),
            Color(red: 212/255, green: 83/255, blue: 126/255),
            Color(red: 75/255, green: 21/255, blue: 40/255)
        ],
        listenColor: Color(red: 232/255, green: 123/255, blue: 168/255),
        speakColor: Color(red: 240/255, green: 160/255, blue: 184/255),
        unlocksAt: 75
    )

    static let obsidian = SemiTheme(
        id: "obsidian",
        name: "Obsidian",
        backgroundTop: Color(red: 10/255, green: 10/255, blue: 10/255),
        backgroundBottom: Color(red: 20/255, green: 20/255, blue: 20/255),
        accent: Color(red: 136/255, green: 135/255, blue: 128/255),
        aura: [
            Color(red: 180/255, green: 178/255, blue: 169/255),
            Color(red: 95/255, green: 94/255, blue: 90/255),
            Color(red: 26/255, green: 25/255, blue: 23/255)
        ],
        listenColor: Color(red: 154/255, green: 152/255, blue: 144/255),
        speakColor: Color(red: 196/255, green: 194/255, blue: 185/255),
        unlocksAt: 100
    )

    static let all: [SemiTheme] = [.midnight, .aurora, .ember, .sakura, .obsidian]
}

struct SemiMilestone: Identifiable, Equatable {
    let percent: Int
    let name: String
    let symbol: String
    let description: String

    var id: Int { percent }

    static let all: [SemiMilestone] = [
        .init(percent: 0, name: "First Words", symbol: "hand.wave.fill", description: "Semi is listening for the first time."),
        .init(percent: 10, name: "Echoes", symbol: "speaker.wave.2.fill", description: "Semi is starting to mirror your phrases."),
        .init(percent: 25, name: "Cadence", symbol: "music.note", description: "Semi matches your speaking pace. Aurora unlocked."),
        .init(percent: 50, name: "Resonance", symbol: "sparkles", description: "Semi can finish your sentences. Ember unlocked."),
        .init(percent: 75, name: "Harmony", symbol: "camera.macro", description: "Rings pulse with your voice rhythm. Sakura unlocked."),
        .init(percent: 90, name: "Almost You", symbol: "star.fill", description: "Semi sounds recognizably like you to others."),
        .init(percent: 100, name: "Cloned", symbol: "seal.fill", description: "Full voice clone unlocked. Obsidian unlocked.")
    ]
}

enum SemiDesign {
    static let theme = SemiTheme.midnight

    static func background(_ theme: SemiTheme = theme) -> LinearGradient {
        LinearGradient(
            colors: [theme.backgroundTop, theme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func progress(for messageCount: Int, stateProgress: Double = 0) -> Double {
        let conversationProgress = min(70, max(0, messageCount - 1) * 7)
        return min(100, Double(conversationProgress) + stateProgress)
    }

    static func milestone(for progress: Double) -> SemiMilestone {
        SemiMilestone.all.last(where: { progress >= Double($0.percent) }) ?? SemiMilestone.all[0]
    }
}

struct SemiGlassButtonStyle: ButtonStyle {
    let theme: SemiTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telka(13, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white.opacity(configuration.isPressed ? 0.09 : 0.05))
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SemiPrimaryButtonStyle: ButtonStyle {
    let theme: SemiTheme
    let isActive: Bool
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.telka(14, weight: .medium))
            .foregroundStyle(isActive ? theme.accent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isActive ? theme.accent.opacity(0.24) : theme.accent)
            .overlay(
                Capsule()
                    .stroke(isActive ? theme.accent.opacity(0.50) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
            .shadow(color: theme.accent.opacity(isActive ? 0.18 : 0.38), radius: 22, x: 0, y: 8)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
    }
}

struct SemiBackground: View {
    let theme: SemiTheme

    var body: some View {
        ZStack {
            SemiDesign.background(theme)
            RadialGradient(
                colors: [theme.aura[0].opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 20,
                endRadius: 280
            )
        }
        .ignoresSafeArea()
    }
}

struct SemiStatusPill: View {
    let label: String
    let dotColor: Color
    let isPulsing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .opacity(isPulsing ? 0.75 : 1)
                .scaleEffect(isPulsing ? 1.16 : 1)
                .animation(
                    isPulsing ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                    value: isPulsing
                )

            Text(label.uppercased())
                .font(AppFont.mono(10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(Capsule())
    }
}

struct SemiProgressStrip: View {
    let theme: SemiTheme
    let progress: Double

    var body: some View {
        let clamped = min(100, max(0, progress))
        let milestone = SemiDesign.milestone(for: clamped)
        let next = SemiMilestone.all.first(where: { Double($0.percent) > clamped })

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text("voice clone")
                        .font(AppFont.telka(12))
                        .foregroundStyle(Color.white.opacity(0.35))

                    Text(milestone.name)
                        .font(AppFont.mono(9, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(theme.accent.opacity(0.25), lineWidth: 1))
                }

                Spacer()

                Text("\(Int(clamped.rounded()))%")
                    .font(AppFont.mono(12, weight: .bold))
                    .foregroundStyle(theme.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: clamped >= 50 ? [theme.aura[2], theme.aura[1], theme.aura[0]] : [theme.accent, theme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, proxy.size.width * clamped / 100))
                        .shadow(color: theme.accent.opacity(0.55), radius: 8)

                    ForEach(SemiMilestone.all.filter { $0.percent > 0 && $0.percent < 100 }) { milestone in
                        Circle()
                            .fill(clamped >= Double(milestone.percent) ? theme.accent : Color.white.opacity(0.25))
                            .frame(width: 5, height: 5)
                            .position(x: proxy.size.width * CGFloat(milestone.percent) / 100, y: 1.5)
                    }
                }
            }
            .frame(height: 3)

            if let next {
                Text("next: \(next.name) at \(next.percent)%")
                    .font(AppFont.telka(10))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
        }
    }
}

struct SemiAuraAvatar<Avatar: View>: View {
    let theme: SemiTheme
    let progress: Double
    let state: PrototypeMessagesCallState
    let avatar: Avatar
    let action: () -> Void

    init(
        theme: SemiTheme,
        progress: Double,
        state: PrototypeMessagesCallState,
        @ViewBuilder avatar: () -> Avatar,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.progress = progress
        self.state = state
        self.avatar = avatar()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                ForEach(Array(ringSizes.enumerated()), id: \.offset) { index, size in
                    Circle()
                        .stroke(ringColor(for: index).opacity(ringOpacity(for: index)), lineWidth: 2)
                        .frame(width: size, height: size)
                        .shadow(color: ringColor(for: index).opacity(0.32), radius: 12 + CGFloat(index * 8))
                        .scaleEffect(state == .listening ? 1.07 : state == .responding ? 1.04 : 1)
                        .animation(
                            .easeInOut(duration: state == .listening ? 0.9 : 1.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.22),
                            value: state
                        )
                }

                avatar
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .background(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [theme.aura[0].opacity(progress >= 50 ? 0.34 : 0.14), theme.backgroundBottom],
                                    center: UnitPoint(x: 0.34, y: 0.30),
                                    startRadius: 2,
                                    endRadius: 96
                                )
                            )
                    )
                    .overlay(Circle().stroke(theme.accent.opacity(progress >= 25 ? 0.35 : 0.14), lineWidth: 1.5))
                    .shadow(color: theme.accent.opacity(glowOpacity), radius: glowRadius)
                    .scaleEffect(state == .idle ? 1 : 1.02)
            }
            .frame(width: 280, height: 280)
        }
        .buttonStyle(.plain)
    }

    private var ringSizes: [CGFloat] {
        if progress < 10 { return [200] }
        if progress < 25 { return [200, 236] }
        return [200, 236, 272]
    }

    private var glowRadius: CGFloat {
        switch progress {
        case 100...: return 56
        case 75...: return 40
        case 50...: return 28
        case 25...: return 16
        default: return 0
        }
    }

    private var glowOpacity: Double {
        progress >= 25 ? 0.42 : 0
    }

    private func ringColor(for index: Int) -> Color {
        switch state {
        case .listening:
            return theme.listenColor
        case .responding:
            return theme.speakColor
        case .idle:
            return theme.aura[min(index, theme.aura.count - 1)]
        }
    }

    private func ringOpacity(for index: Int) -> Double {
        switch state {
        case .idle:
            return [0.35, 0.22, 0.12][min(index, 2)]
        case .listening:
            return [0.75, 0.50, 0.30][min(index, 2)]
        case .responding:
            return [0.65, 0.42, 0.22][min(index, 2)]
        }
    }
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
