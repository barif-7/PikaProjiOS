//
//  PrototypeProviderSettingsViewModelDataTypes.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation

/// Editable Ollama provider connection shown in settings.
struct PrototypeOllamaConnection: Equatable {
    var endpointURL: String
    var model: String
    var apiToken: String
    var label: String
}

struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}

/// Backend service used to load and save the user's Ollama connection.
protocol PrototypeProviderConnectionServicing {
    /// Returns the stored connection, or `nil` when none has been saved yet (404).
    func loadOllamaConnection() async throws -> PrototypeOllamaConnection?
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
