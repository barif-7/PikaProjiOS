//
//  VoiceScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Voice onboarding screen that records and submits a training sample.
struct VoiceScreen: View {
    @ObservedObject var viewModel: PrototypeVoiceViewModel
    @Environment(\.designSystem) private var designSystem

    private let contentMaxWidth: CGFloat = 320

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

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    avatarPreview
                        .padding(.bottom, 28)

                    headerSection

                    quoteSection
                        .padding(.top, 28)

                    controlsSection
                        .padding(.top, 40)
                }
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, designSystem.spacing.xl)
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

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.title)
                .font(designSystem.fonts.telka(32, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)

            Text(viewModel.subtitle)
                .font(designSystem.fonts.telka(15))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.92)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, designSystem.spacing.lg)
    }

    private var quoteSection: some View {
        Text(viewModel.quote)
            .font(designSystem.fonts.telka(28, weight: .medium))
            .foregroundStyle(quoteColor)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controlsSection: some View {
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
                    .minimumScaleFactor(0.9)
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
        .frame(maxWidth: .infinity)
        .padding(.bottom, 55)
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

    private var avatarPreview: some View {
        avatarImage
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let image = viewModel.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if ImportedAsset.semiPortrait.existsInBundle {
            ImportedBitmapImage(asset: .semiPortrait, contentMode: .fill)
        } else {
            Circle()
                .fill(designSystem.colors.accentSecondary)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(titleColor)
                }
        }
    }
}
