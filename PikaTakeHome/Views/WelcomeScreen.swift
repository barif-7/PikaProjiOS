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
    
    private var headingColor: Color { ds.colors.textPrimary }
    private var subtitleColor: Color { ds.colors.textSecondary }
    private var termsColor: Color { ds.colors.textSecondary.opacity(0.5) }
    private var continueFill: Color { ds.colors.accentSecondary }
    private var continueText: Color { ds.colors.textPrimary }

    var body: some View {
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
