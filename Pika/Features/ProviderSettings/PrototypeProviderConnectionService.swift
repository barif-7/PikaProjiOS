//
//  PrototypeProviderConnectionService.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation

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

    func loadOllamaConnection() async throws -> PrototypeOllamaConnection? {
        var request = URLRequest(url: endpointURL)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrototypeProviderSettingsError.invalidResponse
        }

        // 404 means no connection saved yet — return nil so the UI shows empty fields.
        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? decoder.decode(ProviderBackendErrorResponse.self, from: data))?.message
            throw PrototypeProviderSettingsError.backend(
                message: backendMessage ?? String(localized: AppStrings.providerSettingsSaveFailedBody)
            )
        }

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
        try validateSave(response: response, data: data)
    }

    private func validateSave(response: URLResponse, data: Data) throws {
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
