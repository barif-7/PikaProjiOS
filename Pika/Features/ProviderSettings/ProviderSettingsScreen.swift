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
    private let featureFlags = FeatureFlagManager.shared
    private let semiTheme = SemiDesign.theme

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

    private var legacyBody: some View {
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
                                Text(AppStrings.providerSettingsLoading)
                                    .font(designSystem.fonts.telka(13))
                                    .foregroundStyle(designSystem.colors.textSecondary)
                            }
                        } else if let statusText = viewModel.statusText {
                            Text(statusText)
                                .font(designSystem.fonts.telka(13, weight: .medium))
                                .foregroundStyle(designSystem.colors.accentQuote)
                        }

                        Button(action: {
                            viewModel.signOutTapped()
                        }) {
                            Group {
                                if viewModel.isSigningOut {
                                    ProgressView()
                                } else {
                                    Text(AppStrings.providerSettingsSignOut)
                                        .font(designSystem.fonts.telka(15, weight: .black))
                                        .foregroundStyle(designSystem.colors.textPrimary)
                                }
                            }
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

                        if viewModel.isSignedIn {
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
    }

    private var semiBody: some View {
        let progress = viewModel.isTwoFactorEnabled ? 35.0 : viewModel.isSignedIn ? 20.0 : 5.0

        return ZStack {
            SemiBackground(theme: semiTheme)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.backTapped()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Text("Settings")
                        .font(AppFont.telka(17, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.86))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.black.opacity(0.18))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Stats")
                                .font(AppFont.mono(10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.30))

                            HStack(spacing: 8) {
                                semiStat(icon: "mic.fill", label: "Clone", value: "\(Int(progress))%", color: semiTheme.accent)
                                semiStat(icon: "flame.fill", label: "Streak", value: "3d", color: Color(red: 251/255, green: 146/255, blue: 60/255))
                                semiStat(icon: "bolt.fill", label: "Sessions", value: "\(max(1, viewModel.availableModels.count))", color: Color(red: 245/255, green: 158/255, blue: 11/255))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme")
                                .font(AppFont.mono(10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.30))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(SemiTheme.all) { theme in
                                        semiThemeSwatch(theme, isSelected: theme.id == semiTheme.id, isUnlocked: progress >= Double(theme.unlocksAt))
                                    }
                                }
                                .padding(.bottom, 2)
                            }

                            Text("Themes unlock as your voice clone trains.")
                                .font(AppFont.telka(12))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Clone Journey")
                                .font(AppFont.mono(10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.30))

                            ForEach(SemiMilestone.all.prefix(5)) { milestone in
                                semiMilestoneRow(milestone, progress: progress)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Provider")
                                .font(AppFont.mono(10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.30))

                            if let signedInName = viewModel.signedInName ?? viewModel.signedInEmail {
                                Text("Signed in as \(signedInName)")
                                    .font(AppFont.telka(13))
                                    .foregroundStyle(Color.white.opacity(0.42))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            } else {
                                Text(String(localized: AppStrings.providerSettingsSignedOut))
                                    .font(AppFont.telka(13))
                                    .foregroundStyle(Color.white.opacity(0.42))
                            }

                            if viewModel.isSignedIn {
                                semiProviderField(title: AppStrings.providerSettingsEndpoint, text: $viewModel.endpointURL, keyboardType: .URL)
                                semiModelField
                                semiProviderField(title: AppStrings.providerSettingsLabel, text: $viewModel.label)
                                semiProviderField(title: AppStrings.providerSettingsToken, text: $viewModel.apiToken, isSecure: true)
                            }

                            if viewModel.isLoading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(semiTheme.accent)
                                    Text(AppStrings.providerSettingsLoading)
                                        .font(AppFont.telka(13))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                }
                            } else if let statusText = viewModel.statusText {
                                Text(statusText)
                                    .font(AppFont.telka(13, weight: .medium))
                                    .foregroundStyle(semiTheme.accent)
                            }
                        }

                        VStack(spacing: 10) {
                            Button {
                                viewModel.saveTapped()
                            } label: {
                                Text(AppStrings.providerSettingsSave)
                            }
                            .buttonStyle(
                                SemiPrimaryButtonStyle(
                                    theme: semiTheme,
                                    isActive: false,
                                    isEnabled: viewModel.canSave
                                )
                            )
                            .disabled(!viewModel.canSave)

                            Button {
                                viewModel.signOutTapped()
                            } label: {
                                Text(AppStrings.providerSettingsSignOut)
                            }
                            .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                            .disabled(!viewModel.canSignOut)

                            if viewModel.isSignedIn {
                                Button {
                                    viewModel.deleteAccountTapped()
                                } label: {
                                    Text(AppStrings.providerSettingsDeleteAccount)
                                        .foregroundStyle(Color.red.opacity(0.85))
                                }
                                .buttonStyle(SemiGlassButtonStyle(theme: semiTheme))
                                .disabled(!viewModel.canDeleteAccount)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .frame(maxWidth: 430)
        }
    }

    private func semiStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)

                Text(label)
                    .font(AppFont.telka(10))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Text(value)
                .font(AppFont.mono(18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.90))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func semiThemeSwatch(_ theme: SemiTheme, isSelected: Bool, isUnlocked: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SemiDesign.background(theme))
                    .frame(width: 64, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? theme.accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? theme.accent.opacity(0.40) : .clear, radius: 12)

                Circle()
                    .stroke(theme.aura[0].opacity(0.40), lineWidth: 1)
                    .frame(width: 30, height: 30)
                    .offset(y: -17)

                Circle()
                    .fill(theme.accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: theme.accent.opacity(0.8), radius: 8)
                    .offset(y: 25)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .offset(y: 24)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(theme.accent, in: Circle())
                        .offset(x: 20, y: -25)
                }
            }
            .opacity(isUnlocked ? 1 : 0.45)

            Text(theme.name)
                .font(AppFont.telka(10))
                .foregroundStyle(Color.white.opacity(0.50))

            if !isUnlocked {
                Text("\(theme.unlocksAt)%")
                    .font(AppFont.telka(9))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
    }

    private func semiMilestoneRow(_ milestone: SemiMilestone, progress: Double) -> some View {
        let reached = progress >= Double(milestone.percent)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: milestone.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(reached ? semiTheme.accent : Color.white.opacity(0.30))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(milestone.name)
                        .font(AppFont.telka(14, weight: .medium))
                        .foregroundStyle(reached ? Color.white.opacity(0.90) : Color.white.opacity(0.50))

                    Text("\(milestone.percent)%")
                        .font(AppFont.mono(11, weight: .bold))
                        .foregroundStyle(reached ? semiTheme.accent : Color.white.opacity(0.25))
                }

                Text(milestone.description)
                    .font(AppFont.telka(12))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineSpacing(3)
            }

            Spacer()

            if reached {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(semiTheme.accent)
            }
        }
        .padding(14)
        .background(reached ? semiTheme.accent.opacity(0.08) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(reached ? semiTheme.accent.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .opacity(reached ? 1 : 0.52)
    }

    private var semiModelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.providerSettingsModel)
                .font(AppFont.telka(13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))

            HStack(spacing: 8) {
                semiTextField(text: $viewModel.model, isSecure: false, keyboardType: .default)

                Button {
                    viewModel.fetchModelsTapped()
                } label: {
                    Group {
                        if viewModel.isFetchingModels {
                            ProgressView()
                                .tint(semiTheme.accent)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
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

    @ViewBuilder
    private func semiProviderField(
        title: LocalizedStringResource,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.telka(13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))

            semiTextField(text: text, isSecure: isSecure, keyboardType: keyboardType)
        }
    }

    @ViewBuilder
    private func semiTextField(
        text: Binding<String>,
        isSecure: Bool,
        keyboardType: UIKeyboardType
    ) -> some View {
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
        .font(AppFont.telka(16))
        .foregroundStyle(Color.white.opacity(0.90))
        .tint(semiTheme.accent)
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
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
