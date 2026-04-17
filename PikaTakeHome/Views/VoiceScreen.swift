import SwiftUI

struct VoiceScreen: View {
    @ObservedObject var viewModel: PrototypeVoiceViewModel

    var body: some View {
        ZStack {
            AppColor.screenBackgroundElevated.ignoresSafeArea()

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: AppColor.textPrimary,
                    buttonBackground: AppColor.surfaceSecondary.opacity(0.72)
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer(minLength: 18)

                VStack(spacing: 16) {
                    Text(viewModel.title)
                        .font(AppFont.telka(31, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.horizontal, 28)

                    Text(viewModel.subtitle)
                        .font(AppFont.telka(17))
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    QuoteCard(text: viewModel.quote)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                }

                Spacer(minLength: 26)

                VStack(spacing: 14) {
                    switch viewModel.stage {
                    case .prompt:
                        VoiceButton(style: .mic) {
                            viewModel.primaryVoiceActionTapped()
                        }
                    case .recording:
                        VoiceButton(style: .stop) {
                            viewModel.primaryVoiceActionTapped()
                        }

                        Text(AppStrings.voiceListening)
                            .font(AppFont.telka(15, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                    case .complete:
                        VoiceCompleteControls(
                            onRestart: { viewModel.restartTapped() },
                            onConfirm: { viewModel.confirmTapped() },
                            onPlay: {}
                        )
                    }
                }
                .padding(.bottom, 28)
            }
        }
    }
}
