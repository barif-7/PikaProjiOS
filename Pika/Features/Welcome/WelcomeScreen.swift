//
//  WelcomeScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI
import UIKit

/// Entry screen that handles phone sign-in, Google sign-in, and onboarding media.
struct WelcomeScreen: View {
    @ObservedObject var viewModel: PrototypeWelcomeViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStartedOnboardingAudio = false

    @Environment(\.designSystem) private var ds: PikaDesignSystem
    private let featureFlags = FeatureFlagManager.shared
    private let semiTheme = SemiDesign.theme
    
    private var headingColor: Color { ds.colors.textPrimary }
    private var subtitleColor: Color { ds.colors.textSecondary }
    private var termsColor: Color { ds.colors.textSecondary.opacity(0.5) }
    private var continueFill: Color { ds.colors.accentSecondary }
    private var continueText: Color { ds.colors.textPrimary }
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
        .ignoresSafeArea(edges: .top)
        .contentShape(Rectangle())
        .onAppear {
            BitmapImageStore.shared.prewarm(.voiceBackground)
            BitmapImageStore.shared.prewarm(.semiPortrait)
            LoopingVideoStore.shared.prewarm(.onboardingHeroProxy)
            VideoThumbnailStore.shared.prewarm(.onboardingHeroProxy)
            BackgroundAudioStore.shared.prewarm(.onboardingBackgroundAudio)
        }
        .onDisappear {
            hasStartedOnboardingAudio = false
            BackgroundAudioStore.shared.stop(.onboardingBackgroundAudio)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if hasStartedOnboardingAudio {
                    BackgroundAudioStore.shared.play(.onboardingBackgroundAudio)
                }
            case .inactive, .background:
                BackgroundAudioStore.shared.stop(.onboardingBackgroundAudio)
            @unknown default:
                BackgroundAudioStore.shared.stop(.onboardingBackgroundAudio)
            }
        }
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var legacyBody: some View {
        ZStack {
            HeroFace {
                guard !hasStartedOnboardingAudio else { return }
                hasStartedOnboardingAudio = true
                BackgroundAudioStore.shared.play(.onboardingBackgroundAudio)
            }
                .ignoresSafeArea(.keyboard)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.size.height * 0.5, 360))

                    VStack(spacing: 18) {
                        VStack(spacing: 7) {
                            Text(viewModel.title)
                                .font(.custom("Telka Extended", size: 32).weight(.black))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(headingColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(viewModel.subtitle)
                                .font(AppFont.telka(15))
                                .foregroundStyle(subtitleColor)
                        }

                        PhoneField(text: $viewModel.phoneNumber)

                        PrimaryButton(
                            title: AppStrings.welcomeContinue,
                            enabled: viewModel.canContinue && !viewModel.isAuthenticating,
                            textColor: continueText,
                            backgroundColor: continueFill
                        ) {
                            viewModel.continueTapped()
                        }
                        .padding(.top, 2)

                        DividerRow()

                        HStack(spacing: 16) {
                            CircleIconButton(asset: .googleIcon, fallbackSystemName: "g.circle.fill") {
                                viewModel.googleTapped()
                            }
                            .disabled(viewModel.isAuthenticating)
                            .opacity(viewModel.isAuthenticating ? 0.55 : 1)

                            CircleIconButton(asset: .mailIcon, fallbackSystemName: "envelope.fill")
                                .disabled(viewModel.isAuthenticating)
                                .opacity(viewModel.isAuthenticating ? 0.55 : 1)
                        }

                        (
                            Text("Sign in to agree to ")
                                .font(AppFont.telka(12))
                            +
                            Text("terms")
                                .font(AppFont.telka(12, weight: .medium))
                        )
                            .foregroundStyle(termsColor)
                            .padding(.top, 2)

                        if viewModel.isAuthenticating {
                            ProgressView()
                                .padding(.top, 6)
                        } else if let authErrorMessage = viewModel.authErrorMessage {
                            Text(authErrorMessage)
                                .font(AppFont.telka(12))
                                .foregroundStyle(Color.red.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var semiBody: some View {
        ZStack {
            SemiBackground(theme: semiTheme)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [semiTheme.aura[0].opacity(0.24), semiTheme.backgroundBottom],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: 54
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(Circle().stroke(semiTheme.accent.opacity(0.36), lineWidth: 1.5))
                            .shadow(color: semiTheme.accent.opacity(0.28), radius: 28)

                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(semiTheme.accent)
                    }

                    VStack(spacing: 5) {
                        Text("semi")
                            .font(AppFont.telka(32, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.95))

                        Text("Your voice, cloned.")
                            .font(AppFont.telka(14))
                            .foregroundStyle(Color.white.opacity(0.42))
                    }
                }
                .padding(.top, 72)

                Spacer()

                VStack(spacing: 10) {
                    ForEach(
                        [
                            "Talk naturally. Semi listens.",
                            "Semi learns your cadence, tone, and vocabulary.",
                            "The more you talk, the more Semi becomes you."
                        ],
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(AppFont.telka(14))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                VStack(spacing: 14) {
                    PhoneField(text: $viewModel.phoneNumber)
                        .colorScheme(.light)

                    Button {
                        viewModel.continueTapped()
                    } label: {
                        Label(String(localized: AppStrings.welcomeContinue), systemImage: "mic.fill")
                    }
                    .buttonStyle(
                        SemiPrimaryButtonStyle(
                            theme: semiTheme,
                            isActive: false,
                            isEnabled: viewModel.canContinue && !viewModel.isAuthenticating
                        )
                    )
                    .disabled(!viewModel.canContinue || viewModel.isAuthenticating)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.googleTapped()
                        } label: {
                            Label("Google", systemImage: "g.circle.fill")
                        }
                        .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                        .disabled(viewModel.isAuthenticating)

                        Button {
                        } label: {
                            Label("Email", systemImage: "envelope.fill")
                        }
                        .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                        .disabled(viewModel.isAuthenticating)
                    }

                    if viewModel.isAuthenticating {
                        ProgressView()
                            .tint(semiTheme.accent)
                            .padding(.top, 4)
                    } else if let authErrorMessage = viewModel.authErrorMessage {
                        Text(authErrorMessage)
                            .font(AppFont.telka(12))
                            .foregroundStyle(Color.red.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    Text("Sign in to agree to terms")
                        .font(AppFont.telka(12))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: 430)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(
                UIResponder.resignFirstResponder
            ),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
