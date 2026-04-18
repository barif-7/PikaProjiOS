import SwiftUI

struct VoiceScreen: View {
    @ObservedObject var viewModel: PrototypeVoiceViewModel
    @Environment(\.designSystem) private var designSystem

    private var titleColor: Color { designSystem.colors.textPrimary }
    private var subtitleColor: Color { designSystem.colors.textSecondary }
    private var quoteColor: Color { designSystem.colors.accentQuote }
    private var overlayColor: Color { designSystem.colors.surfaceOverlay }

    var body: some View {
        ZStack {
            designSystem.colors.screenBackgroundElevated.ignoresSafeArea()

            if ImportedAsset.voiceBackground.existsInBundle {
                ImportedBitmapImage(asset: .voiceBackground, contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 32)
                    .overlay(overlayColor)
            }

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: titleColor,
                    buttonBackground: designSystem.colors.surfaceChrome
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.top, 51)

                progressLine
                    .padding(.top, -24)

                Spacer(minLength: 56)

                VStack(spacing: 8) {
                    Text(viewModel.title)
                        .font(designSystem.fonts.telka(32, weight: .black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)

                    Text(viewModel.subtitle)
                        .font(designSystem.fonts.telka(15))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, designSystem.spacing.quoteInset)

                if let avatarImage = viewModel.avatarImage {
                    avatarPreview(avatarImage)
                        .padding(.top, 28)
                }

                Spacer(minLength: viewModel.avatarImage == nil ? 96 : 40)

                Text(viewModel.quote)
                    .font(designSystem.fonts.telka(28, weight: .medium))
                    .foregroundStyle(quoteColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 345, alignment: .center)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 92)

                VStack(spacing: 14) {
                    switch viewModel.stage {
                    case .prompt:
                        voicePromptButton {
                            viewModel.primaryVoiceActionTapped()
                        }
                    case .recording:
                        VoiceButton(style: .stop, outerDiameter: designSystem.controlSize.voiceButton, innerDiameter: 62, symbolSize: 20) {
                            viewModel.primaryVoiceActionTapped()
                        }
                        .disabled(viewModel.isTraining)

                        Text(viewModel.recordingStatusText)
                            .font(designSystem.fonts.telka(15, weight: .medium))
                            .foregroundStyle(subtitleColor)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    case .complete:
                        if viewModel.isTraining {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(titleColor)

                                if let statusMessage = viewModel.statusMessage {
                                    Text(statusMessage)
                                        .font(designSystem.fonts.telka(15, weight: .medium))
                                        .foregroundStyle(subtitleColor)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        } else {
                            VoiceCompleteControls(
                                onRestart: { viewModel.restartTapped() },
                                onConfirm: { viewModel.confirmTapped() },
                                onPlay: {}
                            )
                        }
                    }
                }
                .padding(.bottom, 55)
            }
            .padding(.horizontal, designSystem.spacing.voiceScreenInset)
            .padding(.bottom, designSystem.spacing.voiceScreenInset)
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
                    .fill(designSystem.colors.accentSecondary)
                    .frame(width: designSystem.controlSize.voiceButton, height: designSystem.controlSize.voiceButton)

                if ImportedAsset.voiceRecordButton.existsInBundle {
                    ImportedSVGView(asset: .voiceRecordButton)
                        .frame(width: designSystem.controlSize.voiceButton, height: designSystem.controlSize.voiceButton)
                        .allowsHitTesting(false)
                } else {
                    Circle()
                        .fill(titleColor)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: designSystem.controlSize.voiceButton, height: designSystem.controlSize.voiceButton)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isTraining)
    }

    private func avatarPreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}
