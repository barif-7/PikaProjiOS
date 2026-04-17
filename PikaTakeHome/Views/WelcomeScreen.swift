import SwiftUI
import UIKit

struct WelcomeScreen: View {
    @ObservedObject var viewModel: PrototypeWelcomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStartedOnboardingAudio = false

    private let headingColor = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
    private let subtitleColor = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255).opacity(0.6)
    private let termsColor = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255).opacity(0.5)
    private let continueFill = Color(red: 207 / 255, green: 195 / 255, blue: 1.0)
    private let continueText = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)

    var body: some View {
        ZStack {
            HeroFace {
                guard !hasStartedOnboardingAudio else { return }
                hasStartedOnboardingAudio = true
                BackgroundAudioStore.shared.play(.onboardingBackgroundAudio)
            }
                .ignoresSafeArea()
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
                            enabled: viewModel.canContinue,
                            textColor: continueText,
                            backgroundColor: continueFill
                        ) {
                            viewModel.continueTapped()
                        }
                        .padding(.top, 2)

                        DividerRow()

                        HStack(spacing: 16) {
                            CircleIconButton(asset: .googleIcon, fallbackSystemName: "g.circle.fill")
                            CircleIconButton(asset: .mailIcon, fallbackSystemName: "envelope.fill")
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
