//
//  ProviderSettingsScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Settings screen for connecting the backend to an Ollama provider.
struct ProviderSettingsScreen: View {
    @ObservedObject var viewModel: PrototypeProviderSettingsViewModel
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.title)
                                .font(designSystem.fonts.telka(28, weight: .black))
                                .foregroundStyle(designSystem.colors.textPrimary)

                            Text(viewModel.subtitle)
                                .font(designSystem.fonts.telka(15))
                                .foregroundStyle(designSystem.colors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppStrings.providerSettingsAccount)
                                .font(designSystem.fonts.telka(13, weight: .medium))
                                .foregroundStyle(designSystem.colors.textSecondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: AppStrings.providerSettingsSignedInAs))
                                    .font(designSystem.fonts.telka(13))
                                    .foregroundStyle(designSystem.colors.textSecondary)

                                if let signedInName = viewModel.signedInName {
                                    Text(signedInName)
                                        .font(designSystem.fonts.telka(18, weight: .black))
                                        .foregroundStyle(designSystem.colors.textPrimary)
                                }

                                if let signedInEmail = viewModel.signedInEmail {
                                    Text(signedInEmail)
                                        .font(designSystem.fonts.telka(14))
                                        .foregroundStyle(designSystem.colors.textSecondary)
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                            )
                        }

                        if viewModel.isSignedIn {
                            providerField(title: AppStrings.providerSettingsEndpoint, text: $viewModel.endpointURL, keyboardType: .URL)
                            providerField(title: AppStrings.providerSettingsModel, text: $viewModel.model)
                            providerField(title: AppStrings.providerSettingsLabel, text: $viewModel.label)
                            providerField(title: AppStrings.providerSettingsToken, text: $viewModel.apiToken, isSecure: true)
                        } else {
                            Text(String(localized: AppStrings.providerSettingsSignedOut))
                                .font(designSystem.fonts.telka(15))
                                .foregroundStyle(designSystem.colors.textSecondary)
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                                )
                        }

                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading provider settings...")
                                    .font(designSystem.fonts.telka(13))
                                    .foregroundStyle(designSystem.colors.textSecondary)
                            }
                        } else if let statusText = viewModel.statusText {
                            Text(statusText)
                                .font(designSystem.fonts.telka(13, weight: .medium))
                                .foregroundStyle(designSystem.colors.accentQuote)
                        }

                        if viewModel.isSignedIn {
                            Button(action: {
                                viewModel.signOutTapped()
                            }) {
                                Text(AppStrings.providerSettingsSignOut)
                                    .font(designSystem.fonts.telka(15, weight: .black))
                                    .foregroundStyle(designSystem.colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSignOut)
                        }
                    }
                    .padding(.horizontal, designSystem.spacing.xl)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                PrimaryButton(
                    title: AppStrings.providerSettingsSave,
                    enabled: viewModel.canSave,
                    trailingAsset: .arrowTopRight,
                    textColor: designSystem.colors.textInverse,
                    backgroundColor: designSystem.colors.successPrimaryButton,
                    fontSize: 15,
                    height: designSystem.controlSize.secondaryButtonHeight
                ) {
                    viewModel.saveTapped()
                }
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.bottom, 28)
            }
        }
        .task {
            await viewModel.prepare()
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
    private func providerField(
        title: LocalizedStringResource,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(designSystem.fonts.telka(13, weight: .medium))
                .foregroundStyle(designSystem.colors.textSecondary)

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(designSystem.fonts.telka(16))
            .foregroundStyle(designSystem.colors.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
            )
        }
    }
}
