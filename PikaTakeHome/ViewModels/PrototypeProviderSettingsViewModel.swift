//
//  PrototypeProviderSettingsViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation
import SwiftUI

/// Editable Ollama provider connection shown in settings.
struct PrototypeOllamaConnection: Equatable {
    var endpointURL: String
    var model: String
    var apiToken: String
    var label: String
}

private struct BackendOllamaConnectionResponse: Decodable {
    let endpointURL: String
    let model: String?
    let hasAPIToken: Bool
    let label: String?
}

private struct BackendOllamaConnectionRequest: Encodable {
    let endpointURL: String
    let model: String?
    let apiToken: String?
    let label: String?
}

private struct ProviderBackendErrorResponse: Decodable {
    let message: String
}

/// Backend service used to load and save the user's Ollama connection.
protocol PrototypeProviderConnectionServicing {
    func loadOllamaConnection() async throws -> PrototypeOllamaConnection
    func saveOllamaConnection(_ connection: PrototypeOllamaConnection) async throws
}

/// Minimal URLSession abstraction for provider network calls.
protocol PrototypeProviderHTTPSessioning {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: PrototypeProviderHTTPSessioning {}

/// Minimal session-store abstraction for provider settings.
@MainActor
protocol PrototypeProviderSettingsSessionStoring: AnyObject {
    var currentSession: PrototypeAppSession? { get }
    func clearSession()
}

extension PrototypeAppSessionStore: PrototypeProviderSettingsSessionStoring {
    var currentSession: PrototypeAppSession? {
        state.session
    }

    func clearSession() {
        clear()
    }
}

/// Builds provider-connection services for the current session context.
protocol PrototypeProviderConnectionServiceBuilding {
    @MainActor
    func makeService(
        appSessionStore: PrototypeProviderSettingsSessionStoring,
        authConfiguration: AuthBackendConfiguration?
    ) -> PrototypeProviderConnectionServicing?
}

/// HTTP implementation for provider-connection persistence.
actor HTTPPrototypeProviderConnectionService: PrototypeProviderConnectionServicing {
    private let endpointURL: URL
    private let sessionToken: String
    private let session: PrototypeProviderHTTPSessioning
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        endpointURL: URL,
        sessionToken: String,
        session: PrototypeProviderHTTPSessioning = URLSession.shared
    ) {
        self.endpointURL = endpointURL
        self.sessionToken = sessionToken
        self.session = session
    }

    func loadOllamaConnection() async throws -> PrototypeOllamaConnection {
        var request = URLRequest(url: endpointURL)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(BackendOllamaConnectionResponse.self, from: data)
        return PrototypeOllamaConnection(
            endpointURL: decoded.endpointURL,
            model: decoded.model ?? "",
            apiToken: "",
            label: decoded.label ?? ""
        )
    }

    func saveOllamaConnection(_ connection: PrototypeOllamaConnection) async throws {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            BackendOllamaConnectionRequest(
                endpointURL: connection.endpointURL,
                model: connection.model.nilIfBlank,
                apiToken: connection.apiToken.nilIfBlank,
                label: connection.label.nilIfBlank
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrototypeProviderSettingsError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? decoder.decode(ProviderBackendErrorResponse.self, from: data))?.message
            throw PrototypeProviderSettingsError.backend(
                message: backendMessage ?? String(localized: AppStrings.providerSettingsSaveFailedBody)
            )
        }
    }
}

/// Builds the provider settings service from the current authenticated session.
struct PrototypeProviderConnectionServiceFactory: PrototypeProviderConnectionServiceBuilding {
    @MainActor
    static func makeDefault(
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load(),
        appSessionStore: PrototypeProviderSettingsSessionStoring
    ) -> PrototypeProviderConnectionServicing? {
        guard
            let authConfiguration,
            let sessionToken = appSessionStore.currentSession?.sessionToken,
            !sessionToken.isEmpty
        else {
            return nil
        }

        return HTTPPrototypeProviderConnectionService(
            endpointURL: authConfiguration.baseURL
                .appendingPathComponent("provider-connections")
                .appendingPathComponent("ollama"),
            sessionToken: sessionToken
        )
    }

    @MainActor
    func makeService(
        appSessionStore: PrototypeProviderSettingsSessionStoring,
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load()
    ) -> PrototypeProviderConnectionServicing? {
        Self.makeDefault(
            authConfiguration: authConfiguration,
            appSessionStore: appSessionStore
        )
    }
}

/// User-facing provider settings failures.
enum PrototypeProviderSettingsError: LocalizedError {
    case signedOut
    case invalidResponse
    case backend(message: String)

    var errorDescription: String? {
        switch self {
        case .signedOut:
            return String(localized: AppStrings.providerSettingsSignedOut)
        case .invalidResponse:
            return String(localized: AppStrings.providerSettingsSaveFailedBody)
        case let .backend(message):
            return message
        }
    }
}

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
    @Published private(set) var statusText: String?
    @Published var alert: PrototypeCameraAlert?

    var onBackRequested: (() -> Void)?
    var onSignedOut: (() -> Void)?

    private let appSessionStore: PrototypeProviderSettingsSessionStoring
    private let authService: PrototypeGoogleAuthenticating?
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
        serviceBuilder: PrototypeProviderConnectionServiceBuilding = PrototypeProviderConnectionServiceFactory(),
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load()
    ) {
        let resolvedAppSessionStore = appSessionStore ?? PrototypeAppSessionStore.shared

        self.appSessionStore = resolvedAppSessionStore
        self.authService = authService ?? PrototypeGoogleAuthServiceFactory.makeDefault()
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
        !isSaving && !endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isSignedIn
    }

    var canSignOut: Bool {
        !isSaving && !isSigningOut && isSignedIn
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
        guard let service else {
            statusText = String(localized: AppStrings.providerSettingsSignedOut)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let connection = try await service.loadOllamaConnection()
            endpointURL = connection.endpointURL
            model = connection.model
            apiToken = connection.apiToken
            label = connection.label
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

    private func refreshSession() {
        session = appSessionStore.currentSession
        service = serviceBuilder.makeService(
            appSessionStore: appSessionStore,
            authConfiguration: authConfiguration
        )
    }

    private func clearSignedInState() {
        session = nil
        service = nil
        endpointURL = ""
        model = ""
        apiToken = ""
        label = ""
        hasLoaded = true
    }
}
