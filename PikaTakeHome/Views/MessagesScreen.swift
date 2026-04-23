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

    var body: some View {
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
                    if viewModel.showsProviderSettingsButton {
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

    private var avatarView: some View {
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
