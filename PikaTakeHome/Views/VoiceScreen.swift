import SwiftUI

struct VoiceScreen: View {
    @ObservedObject var viewModel: PrototypeVoiceViewModel

    private let titleColor = Color(red: 13.0 / 255.0, green: 13.0 / 255.0, blue: 13.0 / 255.0)
    private let subtitleColor = Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 34.0 / 255.0).opacity(0.6)
    private let quoteColor = Color(red: 128.0 / 255.0, green: 110.0 / 255.0, blue: 202.0 / 255.0)
    private let overlayColor = Color(red: 252.0 / 255.0, green: 250.0 / 255.0, blue: 247.0 / 255.0).opacity(0.9)

    var body: some View {
        ZStack {
            AppColor.screenBackgroundElevated.ignoresSafeArea()

            if ImportedAsset.voiceBackground.existsInBundle {
                ImportedBitmapImage(asset: .voiceBackground, contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 34)
                    .overlay(overlayColor)
            }

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: titleColor,
                    buttonBackground: Color.white.opacity(0.40)
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, 24)
                .padding(.top, 51)

                progressLine
                    .padding(.top, -24)

                Spacer(minLength: 56)

                VStack(spacing: 8) {
                    Text(viewModel.title)
                        .font(.custom("Telka Extended", size: 32).weight(.black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(titleColor)
                        .lineLimit(3)
                        .padding(.horizontal, 24)

                    Text(viewModel.subtitle)
                        .font(AppFont.telka(15))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 62)
                }

                Spacer(minLength: 96)

                Text(viewModel.quote)
                    .font(.custom("Telka Extended", size: 28).weight(.medium))
                    .foregroundStyle(quoteColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .lineLimit(3)
                    .padding(.horizontal, 24)

                Spacer(minLength: 92)

                VStack(spacing: 14) {
                    switch viewModel.stage {
                    case .prompt:
                        voicePromptButton {
                            viewModel.primaryVoiceActionTapped()
                        }
                    case .recording:
                        VoiceButton(style: .stop, outerDiameter: 80, innerDiameter: 62, symbolSize: 20) {
                            viewModel.primaryVoiceActionTapped()
                        }

                        Text(AppStrings.voiceListening)
                            .font(AppFont.telka(15, weight: .medium))
                            .foregroundStyle(subtitleColor)
                            .lineLimit(3)
                    case .complete:
                        VoiceCompleteControls(
                            onRestart: { viewModel.restartTapped() },
                            onConfirm: { viewModel.confirmTapped() },
                            onPlay: {}
                        )
                    }
                }
                .padding(.bottom, 55)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var progressLine: some View {
        if ImportedAsset.progressLine.existsInBundle {
            ImportedSVGView(asset: .progressLine)
                .frame(width: 159, height: 2)
        }
    }

    private func voicePromptButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppColor.accentSecondary)
                    .frame(width: 80, height: 80)

                if ImportedAsset.voiceRecordButton.existsInBundle {
                    ImportedSVGView(asset: .voiceRecordButton)
                        .frame(width: 80, height: 80)
                        .allowsHitTesting(false)
                } else {
                    Circle()
                        .fill(titleColor)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 80, height: 80)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
