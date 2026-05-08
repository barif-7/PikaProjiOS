//
//  ProviderSettingsScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI
import UIKit

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
                            modelField
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

                        if viewModel.isSignedIn {
                            twoFactorSection
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

                            Button(action: {
                                viewModel.deleteAccountTapped()
                            }) {
                                Group {
                                    if viewModel.isDeleting {
                                        ProgressView()
                                    } else {
                                        Text(AppStrings.providerSettingsDeleteAccount)
                                            .font(designSystem.fonts.telka(15, weight: .black))
                                    }
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canDeleteAccount)
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
        .confirmationDialog(
            String(localized: AppStrings.providerSettingsDeleteAccountTitle),
            isPresented: $viewModel.showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: AppStrings.providerSettingsDeleteAccountConfirm), role: .destructive) {
                viewModel.confirmDeleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppStrings.providerSettingsDeleteAccountMessage)
        }
        .sheet(isPresented: $viewModel.showModelPicker) {
            modelPickerSheet
        }
    }

    private var twoFactorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.twoFactorTitle)
                .font(designSystem.fonts.telka(13, weight: .medium))
                .foregroundStyle(designSystem.colors.textSecondary)

            VStack(alignment: .leading, spacing: 14) {
                Text(AppStrings.twoFactorSubtitle)
                    .font(designSystem.fonts.telka(14))
                    .foregroundStyle(designSystem.colors.textSecondary)

                if viewModel.isEnrollingTwoFactor {
                    Text(AppStrings.twoFactorSetupTitle)
                        .font(designSystem.fonts.telka(14, weight: .medium))
                        .foregroundStyle(designSystem.colors.textPrimary)

                    Text(AppStrings.twoFactorSetupBody)
                        .font(designSystem.fonts.telka(13))
                        .foregroundStyle(designSystem.colors.textSecondary)

                    if let qrCodeImage = viewModel.twoFactorQRCodeImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    if let manualEntryKey = viewModel.twoFactorManualEntryKey {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppStrings.twoFactorManualKey)
                                .font(designSystem.fonts.telka(13, weight: .medium))
                                .foregroundStyle(designSystem.colors.textSecondary)

                            Text(manualEntryKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(designSystem.colors.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                } else if viewModel.isTwoFactorEnabled {
                    Text(AppStrings.twoFactorEnabled)
                        .font(designSystem.fonts.telka(14))
                        .foregroundStyle(designSystem.colors.textPrimary)

                    if !viewModel.isTwoFactorVerified {
                        Text(AppStrings.twoFactorVerificationRequired)
                            .font(designSystem.fonts.telka(13))
                            .foregroundStyle(designSystem.colors.textSecondary)
                    }
                }

                if viewModel.isEnrollingTwoFactor || viewModel.isTwoFactorEnabled {
                    providerField(
                        title: AppStrings.twoFactorCode,
                        text: $viewModel.twoFactorCode,
                        keyboardType: .numberPad
                    )
                }

                if let statusText = viewModel.twoFactorStatusText {
                    Text(statusText)
                        .font(designSystem.fonts.telka(13, weight: .medium))
                        .foregroundStyle(designSystem.colors.accentQuote)
                }

                HStack(spacing: 12) {
                    if !viewModel.isTwoFactorEnabled && !viewModel.isEnrollingTwoFactor {
                        actionButton(title: AppStrings.twoFactorEnable) {
                            viewModel.enableTwoFactorTapped()
                        }
                    } else if viewModel.isEnrollingTwoFactor {
                        actionButton(
                            title: AppStrings.twoFactorConfirm,
                            enabled: viewModel.canSubmitTwoFactorCode
                        ) {
                            viewModel.confirmTwoFactorTapped()
                        }
                    } else {
                        actionButton(
                            title: AppStrings.twoFactorVerify,
                            enabled: viewModel.canSubmitTwoFactorCode && !viewModel.isTwoFactorVerified
                        ) {
                            viewModel.verifyTwoFactorTapped()
                        }

                        actionButton(title: AppStrings.twoFactorDisable) {
                            viewModel.disableTwoFactorTapped()
                        }
                    }
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
    }

    private var modelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.providerSettingsModel)
                .font(designSystem.fonts.telka(13, weight: .medium))
                .foregroundStyle(designSystem.colors.textSecondary)

            HStack(spacing: 8) {
                TextField("", text: $viewModel.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(designSystem.fonts.telka(16))
                    .foregroundStyle(designSystem.colors.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                    )

                Button {
                    viewModel.fetchModelsTapped()
                } label: {
                    Group {
                        if viewModel.isFetchingModels {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(designSystem.colors.textPrimary)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.isFetchingModels
                        || viewModel.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private var modelPickerSheet: some View {
        NavigationView {
            List(viewModel.availableModels, id: \.self) { modelName in
                Button {
                    viewModel.model = modelName
                    viewModel.showModelPicker = false
                } label: {
                    HStack {
                        Text(modelName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.model == modelName {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(String(localized: AppStrings.providerSettingsModelPickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showModelPicker = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(
        title: LocalizedStringResource,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(designSystem.fonts.telka(14, weight: .black))
                .foregroundStyle(designSystem.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(enabled ? 0.7 : 0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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
            .onChange(of: text.wrappedValue) { _, newValue in
                if keyboardType == .numberPad {
                    let digitsOnly = newValue.filter(\.isNumber)
                    let limited = String(digitsOnly.prefix(6))
                    if limited != newValue {
                        text.wrappedValue = limited
                    }
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
