//
//  MessagesScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Voice-first chat screen for talking with the generated AI self.
struct MessagesScreen: View {
    @ObservedObject var viewModel: PrototypeMessagesViewModel
    @Environment(\.designSystem) private var designSystem
    private let featureFlags = FeatureFlagManager.shared
    private let semiTheme = SemiDesign.theme

    private var usesSemiDesign: Bool {
        featureFlags.isEnabled(.base44DesignUpgrade)
    }

    var body: some View {
        Group {
            if usesSemiDesign {
                semiBody
            } else {
                legacyBody
            }
        }
        .alert(item: $viewModel.alert) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.alert = nil
                }
            )
        }
        .task {
            await viewModel.prepareConversation()
        }
    }

    private var legacyBody: some View {
        ZStack {
            designSystem.colors.screenBackgroundElevated.ignoresSafeArea()

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: designSystem.colors.textPrimary,
                    buttonBackground: designSystem.colors.surfaceChrome
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.top, 20)
                .overlay(alignment: .topTrailing) {
                    Button {
                        viewModel.openProviderSettingsTapped()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(designSystem.colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(designSystem.colors.surfaceChrome, in: RoundedRectangle(cornerRadius: designSystem.radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: designSystem.radius.sm, style: .continuous)
                                    .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, designSystem.spacing.xl)
                    .padding(.top, 20)
                }

                VStack(spacing: 10) {
                    avatarView
                        .padding(.top, 24)

                    Text(viewModel.title)
                        .font(designSystem.fonts.telka(30, weight: .black))
                        .foregroundStyle(designSystem.colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, designSystem.spacing.xl)

                    Text(viewModel.subtitle)
                        .font(designSystem.fonts.telka(15))
                        .foregroundStyle(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, designSystem.spacing.xl)

                    Text(viewModel.statusText)
                        .font(designSystem.fonts.telka(13, weight: .medium))
                        .foregroundStyle(designSystem.colors.accentQuote)
                        .padding(.top, 4)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            voiceBubble(message)
                        }
                    }
                    .padding(.horizontal, designSystem.spacing.xl)
                    .padding(.vertical, 20)
                }

                Text(viewModel.hint)
                    .font(designSystem.fonts.telka(13))
                    .foregroundStyle(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, designSystem.spacing.xl)
                    .padding(.bottom, 18)

                VStack(spacing: 12) {
                    PrimaryButton(
                        title: viewModel.primaryButtonTitle,
                        enabled: viewModel.isPrimaryButtonEnabled,
                        trailingAsset: .arrowTopRight,
                        textColor: designSystem.colors.textInverse,
                        backgroundColor: designSystem.colors.successPrimaryButton,
                        fontSize: 15,
                        height: designSystem.controlSize.secondaryButtonHeight
                    ) {
                        viewModel.primaryActionTapped()
                    }

                    SecondaryButton(title: AppStrings.messagesEndCall, trailingAsset: .shareIcon) {
                        viewModel.endCallTapped()
                    }

                    if viewModel.showsRetrainVoiceButton {
                        SecondaryButton(title: AppStrings.messagesRetrainVoice, trailingAsset: .arrowTopRight) {
                            viewModel.retrainVoiceTapped()
                        }
                    }
                }
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var semiBody: some View {
        let progress = SemiDesign.progress(
            for: viewModel.messages.count,
            stateProgress: viewModel.callState == .responding ? 4 : viewModel.callState == .listening ? 2 : 0
        )

        return ZStack {
            SemiBackground(theme: semiTheme)

            VStack(spacing: 0) {
                semiTopBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 8)

                SemiAuraAvatar(
                    theme: semiTheme,
                    progress: progress,
                    state: viewModel.callState
                ) {
                    semiAvatarImage
                } action: {
                    viewModel.primaryActionTapped()
                }
                .frame(maxHeight: 320)

                Text(semiStateLabel)
                    .font(AppFont.telka(14))
                    .foregroundStyle(semiStateColor.opacity(0.85))
                    .frame(height: 24)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(viewModel.messages.suffix(4)) { message in
                            semiBubble(message)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 120, maxHeight: 190)

                SemiProgressStrip(theme: semiTheme, progress: progress)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                VStack(spacing: 14) {
                    Button {
                        viewModel.primaryActionTapped()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.callState != .idle {
                                Circle()
                                    .fill(semiStateColor)
                                    .frame(width: 7, height: 7)
                            }
                            Text(semiPrimaryLabel)
                        }
                    }
                    .buttonStyle(
                        SemiPrimaryButtonStyle(
                            theme: semiTheme,
                            isActive: viewModel.callState != .idle,
                            isEnabled: viewModel.isPrimaryButtonEnabled
                        )
                    )
                    .disabled(!viewModel.isPrimaryButtonEnabled)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.endCallTapped()
                        } label: {
                            Label("Step Away", systemImage: "phone.down.fill")
                        }
                        .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))

                        Button {
                            viewModel.openProviderSettingsTapped()
                        } label: {
                            Label("Clone Stats", systemImage: "chart.bar.fill")
                        }
                        .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                    }

                    if viewModel.showsRetrainVoiceButton {
                        Button {
                            viewModel.retrainVoiceTapped()
                        } label: {
                            Label(String(localized: AppStrings.messagesRetrainVoice), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: 430)
        }
    }

    private var semiTopBar: some View {
        HStack {
            Button {
                viewModel.backTapped()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            SemiStatusPill(
                label: semiStatusLabel,
                dotColor: semiStateColor,
                isPulsing: viewModel.callState != .idle
            )

            Text("3")
                .font(AppFont.mono(10, weight: .bold))
                .foregroundStyle(Color(red: 251/255, green: 146/255, blue: 60/255))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(red: 251/255, green: 146/255, blue: 60/255).opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 251/255, green: 146/255, blue: 60/255).opacity(0.25), lineWidth: 1)
                )

            Spacer()

            Button {
                viewModel.openProviderSettingsTapped()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var semiAvatarImage: some View {
        Group {
            if let avatarImage = viewModel.avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else if ImportedAsset.semiPortrait.existsInBundle {
                ImportedBitmapImage(asset: .semiPortrait, contentMode: .fill)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [semiTheme.aura[0].opacity(0.32), semiTheme.backgroundBottom],
                                center: UnitPoint(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 90
                            )
                        )
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .medium))
                        Text("semi")
                            .font(AppFont.mono(9, weight: .bold))
                    }
                    .foregroundStyle(semiTheme.accent.opacity(0.75))
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.updateAvatarTapped()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(semiTheme.accent, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .offset(x: -10, y: -10)
        }
    }

    private func semiBubble(_ message: PrototypeVoiceChatMessage) -> some View {
        let isUser = message.speaker == .user
        let foreground = isUser ? Color.white.opacity(0.90) : Color.white.opacity(0.75)
        let background = isUser ? semiTheme.accent.opacity(0.15) : Color.white.opacity(0.06)
        let border = isUser ? semiTheme.accent.opacity(0.30) : Color.white.opacity(0.10)

        return HStack {
            if isUser {
                Spacer(minLength: 42)
            }

            Text(message.text)
                .font(AppFont.telka(14))
                .lineSpacing(3)
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(border, lineWidth: 1)
                )

            if !isUser {
                Spacer(minLength: 42)
            }
        }
    }

    private var semiStatusLabel: String {
        switch viewModel.callState {
        case .idle:
            return "ready"
        case .listening:
            return "listening..."
        case .responding:
            return "speaking now"
        }
    }

    private var semiStateLabel: String {
        switch viewModel.callState {
        case .idle:
            return "tap to begin"
        case .listening:
            return "I'm listening..."
        case .responding:
            return "speaking now"
        }
    }

    private var semiPrimaryLabel: String {
        switch viewModel.callState {
        case .idle, .responding:
            return "Start Talking"
        case .listening:
            return "Listening..."
        }
    }

    private var semiStateColor: Color {
        switch viewModel.callState {
        case .idle:
            return Color.white.opacity(0.30)
        case .listening:
            return Color(red: 245/255, green: 158/255, blue: 11/255)
        case .responding:
            return Color(red: 251/255, green: 146/255, blue: 60/255)
        }
    }

    private var avatarView: some View {
        Button {
            viewModel.updateAvatarTapped()
        } label: {
            Group {
                if let avatarImage = viewModel.avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                } else if ImportedAsset.semiPortrait.existsInBundle {
                    ImportedBitmapImage(asset: .semiPortrait, contentMode: .fill)
                } else {
                    Circle()
                        .fill(designSystem.colors.accentSecondary)
                        .overlay {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(designSystem.colors.textPrimary)
                        }
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.65), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(designSystem.colors.accentQuote, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func voiceBubble(_ message: PrototypeVoiceChatMessage) -> some View {
        let isUser = message.speaker == .user

        return HStack {
            if isUser {
                Spacer(minLength: 40)
            }

            Text(message.text)
                .font(designSystem.fonts.telka(15))
                .foregroundStyle(isUser ? designSystem.colors.textInverse : designSystem.colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isUser ? designSystem.colors.successPrimaryButton : Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isUser ? Color.clear : designSystem.colors.borderSubtle, lineWidth: 1)
                )

            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
}
