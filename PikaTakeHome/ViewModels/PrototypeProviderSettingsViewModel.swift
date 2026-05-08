//
//  PrototypeProviderSettingsViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
/// View model for viewing and editing the authenticated user's Ollama connection.
final class PrototypeProviderSettingsViewModel: ObservableObject {
    @Published var endpointURL = ""
    @Published var model = ""
    @Published var apiToken = ""
    @Published var label = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isSigningOut = false
    @Published private(set) var isDeleting = false
    @Published private(set) var statusText: String?
    @Published var twoFactorCode = ""
    @Published private(set) var isTwoFactorEnabled = false
    @Published private(set) var isTwoFactorVerified = false
    @Published private(set) var isEnrollingTwoFactor = false
    @Published private(set) var twoFactorManualEntryKey: String?
    @Published private(set) var twoFactorQRCodeImage: UIImage?
    @Published private(set) var twoFactorStatusText: String?
    @Published var alert: PrototypeCameraAlert?
    @Published var showDeleteAccountConfirmation = false
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var isFetchingModels = false
    @Published var showModelPicker = false

    var onBackRequested: (() -> Void)?
    var onSignedOut: (() -> Void)?
    var onAccountDeleted: (() -> Void)?

    private let appSessionStore: PrototypeProviderSettingsSessionStoring
    private let authService: PrototypeGoogleAuthenticating?
    private let twoFactorService: PrototypeTwoFactorServicing
    private let serviceBuilder: PrototypeProviderConnectionServiceBuilding
    private let authConfiguration: AuthBackendConfiguration?
    private var service: PrototypeProviderConnectionServicing?
    private var session: PrototypeAppSession?
    private var hasLoaded = false

    let title = AppStrings.providerSettingsTitle
    let subtitle = AppStrings.providerSettingsSubtitle

    init(
        service: PrototypeProviderConnectionServicing? = nil,
        appSessionStore: PrototypeProviderSettingsSessionStoring? = nil,
        authService: PrototypeGoogleAuthenticating? = nil,
        twoFactorService: PrototypeTwoFactorServicing = PrototypeTwoFactorServiceFactory.makeDefault(),
        serviceBuilder: PrototypeProviderConnectionServiceBuilding = PrototypeProviderConnectionServiceFactory(),
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load()
    ) {
        let resolvedAppSessionStore = appSessionStore ?? PrototypeAppSessionStore.shared

        self.appSessionStore = resolvedAppSessionStore
        self.authService = authService ?? PrototypeGoogleAuthServiceFactory.makeDefault()
        self.twoFactorService = twoFactorService
        self.serviceBuilder = serviceBuilder
        self.authConfiguration = authConfiguration
        self.session = resolvedAppSessionStore.currentSession
        self.service = service ?? serviceBuilder.makeService(
            appSessionStore: resolvedAppSessionStore,
            authConfiguration: authConfiguration
        )
    }

    var isSignedIn: Bool {
        session != nil
    }

    var signedInName: String? {
        session?.user.displayName.nilIfBlank
    }

    var signedInEmail: String? {
        session?.user.email.nilIfBlank
    }

    var canSave: Bool {
        !isSaving
            && !endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isSignedIn
            && isTwoFactorSatisfied
    }

    var canSignOut: Bool {
        !isSaving && !isSigningOut && !isDeleting && isSignedIn && isTwoFactorSatisfied
    }

    var canDeleteAccount: Bool {
        !isDeleting && !isSaving && !isSigningOut && isSignedIn && isTwoFactorSatisfied
    }

    var canSubmitTwoFactorCode: Bool {
        !twoFactorCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isTwoFactorSatisfied: Bool {
        !isTwoFactorEnabled || isTwoFactorVerified
    }

    func save() async {
        guard canSave, let service else { return }

        isSaving = true
        statusText = nil
        defer { isSaving = false }

        do {
            try await service.saveOllamaConnection(
                PrototypeOllamaConnection(
                    endpointURL: endpointURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                    apiToken: apiToken.trimmingCharacters(in: .whitespacesAndNewlines),
                    label: label.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            apiToken = ""
            statusText = String(localized: AppStrings.providerSettingsSaved)
        } catch {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.providerSettingsSaveFailedTitle),
                message: error.localizedDescription.isEmpty
                    ? String(localized: AppStrings.providerSettingsSaveFailedBody)
                    : error.localizedDescription
            )
        }
    }

    func signOut() async {
        guard let session else { return }

        isSigningOut = true
        defer { isSigningOut = false }

        await authService?.signOut(sessionToken: session.sessionToken)
        appSessionStore.clearSession()
        clearSignedInState()
        statusText = String(localized: AppStrings.providerSettingsSignedOutStatus)
        onSignedOut?()
    }

    func prepare() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        refreshSession()
        refreshTwoFactorState()
        guard let service else {
            statusText = String(localized: AppStrings.providerSettingsSignedOut)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if let connection = try await service.loadOllamaConnection() {
                endpointURL = connection.endpointURL
                model = connection.model
                apiToken = connection.apiToken
                label = connection.label
            }
        } catch {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.providerSettingsLoadFailedTitle),
                message: error.localizedDescription.isEmpty
                    ? String(localized: AppStrings.providerSettingsLoadFailedBody)
                    : error.localizedDescription
            )
        }
    }

    func saveTapped() {
        Task {
            await save()
        }
    }

    func backTapped() {
        onBackRequested?()
    }

    func signOutTapped() {
        Task {
            await signOut()
        }
    }

    func deleteAccountTapped() {
        showDeleteAccountConfirmation = true
    }

    func confirmDeleteAccount() {
        Task {
            await deleteAccount()
        }
    }

    func deleteAccount() async {
        guard let session else { return }
        isDeleting = true
        defer { isDeleting = false }

        // Best-effort server-side deletion; clear local state regardless.
        try? await authService?.deleteAccount(sessionToken: session.sessionToken)
        twoFactorService.disable(for: session.user)
        appSessionStore.clearSession()
        clearSignedInState()
        onAccountDeleted?()
    }

    func fetchModelsTapped() {
        Task {
            await fetchModels()
        }
    }

    func fetchModels() async {
        let endpoint = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty, let baseURL = URL(string: endpoint) else {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.providerSettingsFetchModelsFailedTitle),
                message: String(localized: AppStrings.providerSettingsFetchModelsFailedBody)
            )
            return
        }

        isFetchingModels = true
        defer { isFetchingModels = false }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode) else {
                throw PrototypeProviderSettingsError.invalidResponse
            }
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            availableModels = decoded.models.map(\.name)
            if availableModels.isEmpty {
                alert = PrototypeCameraAlert(
                    title: String(localized: AppStrings.providerSettingsFetchModelsFailedTitle),
                    message: String(localized: AppStrings.providerSettingsNoModelsFound)
                )
            } else {
                showModelPicker = true
            }
        } catch {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.providerSettingsFetchModelsFailedTitle),
                message: error.localizedDescription.isEmpty
                    ? String(localized: AppStrings.providerSettingsFetchModelsFailedBody)
                    : error.localizedDescription
            )
        }
    }

    func enableTwoFactorTapped() {
        guard let user = session?.user else { return }
        do {
            let status = try twoFactorService.beginEnrollment(for: user)
            applyTwoFactorStatus(status)
            isTwoFactorVerified = false
            twoFactorCode = ""
            twoFactorStatusText = nil
        } catch {
            presentTwoFactorError(error)
        }
    }

    func confirmTwoFactorTapped() {
        guard let user = session?.user else { return }
        do {
            let status = try twoFactorService.confirmEnrollment(
                code: twoFactorCode,
                for: user
            )
            applyTwoFactorStatus(status)
            isTwoFactorVerified = true
            twoFactorCode = ""
            twoFactorStatusText = String(localized: AppStrings.twoFactorEnrollmentConfirmed)
        } catch {
            presentTwoFactorError(error)
        }
    }

    func verifyTwoFactorTapped() {
        guard let user = session?.user else { return }
        do {
            try twoFactorService.verify(code: twoFactorCode, for: user)
            isTwoFactorVerified = true
            twoFactorCode = ""
            twoFactorStatusText = String(localized: AppStrings.twoFactorVerificationPassed)
        } catch {
            presentTwoFactorError(error)
        }
    }

    func disableTwoFactorTapped() {
        guard let user = session?.user else { return }
        twoFactorService.disable(for: user)
        refreshTwoFactorState()
        twoFactorCode = ""
        isTwoFactorVerified = false
        twoFactorStatusText = String(localized: AppStrings.twoFactorDisabled)
    }

    private func refreshSession() {
        session = appSessionStore.currentSession
        service = serviceBuilder.makeService(
            appSessionStore: appSessionStore,
            authConfiguration: authConfiguration
        )
    }

    private func refreshTwoFactorState() {
        let status = twoFactorService.status(for: session?.user)
        applyTwoFactorStatus(status)
        if !status.isEnabled {
            isTwoFactorVerified = false
        }
    }

    private func applyTwoFactorStatus(_ status: PrototypeTwoFactorStatus) {
        isTwoFactorEnabled = status.isEnabled
        isEnrollingTwoFactor = !status.isEnabled && status.manualEntryKey != nil
        twoFactorManualEntryKey = status.manualEntryKey
        twoFactorQRCodeImage = status.qrCodeImage
        if !status.isEnabled {
            twoFactorStatusText = twoFactorStatusText?.nilIfBlank
        }
    }

    private func presentTwoFactorError(_ error: Error) {
        twoFactorStatusText = error.localizedDescription.isEmpty
            ? String(localized: AppStrings.twoFactorInvalidCode)
            : error.localizedDescription
    }

    private func clearSignedInState() {
        session = nil
        service = nil
        endpointURL = ""
        model = ""
        apiToken = ""
        label = ""
        twoFactorCode = ""
        isTwoFactorEnabled = false
        isTwoFactorVerified = false
        isEnrollingTwoFactor = false
        twoFactorManualEntryKey = nil
        twoFactorQRCodeImage = nil
        twoFactorStatusText = nil
        availableModels = []
        showModelPicker = false
        hasLoaded = true
    }
}
