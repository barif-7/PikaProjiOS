//
//  PrototypeFlowModels.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import AuthenticationServices
import Security
import SwiftUI
import UIKit

/// Top-level destinations managed by `PrototypeCoordinator`.
enum PrototypeRoute: Equatable {
    case welcome
    case camera
    case voice(PrototypeVoiceStage)
    case success
    case messages
    case providerSettings
}

/// Sub-state for the voice onboarding step.
enum PrototypeVoiceStage: Equatable {
    case prompt
    case recording
    case complete
}

/// Camera processing state shown while preparing an avatar from the selfie.
enum PrototypeCameraAvatarState: Equatable {
    case idle
    case loading
    case success
}

/// Localized alert payload used by the camera/avatar flow.
struct PrototypeCameraAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Central typed access point for localized strings used by the prototype.
enum AppStrings {
    static let welcomeTitle = LocalizedStringResource("prototype.welcome.title")
    static let welcomeSubtitle = LocalizedStringResource("prototype.welcome.subtitle")
    static let welcomeContinue = LocalizedStringResource("prototype.welcome.continue")
    static let welcomeTerms = LocalizedStringResource("prototype.welcome.terms")
    static let phoneNumberPlaceholder = LocalizedStringResource("prototype.welcome.phone_placeholder")
    static let welcomeGoogleAuthFailed = LocalizedStringResource("prototype.welcome.google_auth_failed")
    static let welcomeGoogleUnavailable = LocalizedStringResource("prototype.welcome.google_unavailable")
    static let continueWith = LocalizedStringResource("prototype.shared.continue_with")
    static let cameraLoading = LocalizedStringResource("prototype.camera.loading")
    static let cameraSuccess = LocalizedStringResource("prototype.camera.success")
    static let cameraNoFaceTitle = LocalizedStringResource("prototype.camera.no_face_title")
    static let cameraNoFaceMessage = LocalizedStringResource("prototype.camera.no_face_message")
    static let cameraMultipleFacesMessage = LocalizedStringResource("prototype.camera.multiple_faces_message")
    static let cameraCaptureFailedTitle = LocalizedStringResource("prototype.camera.capture_failed")
    static let cameraCaptureFailedBody = LocalizedStringResource("prototype.camera.capture_failed_body")
    static let cameraImagePlaygroundUnavailableTitle = LocalizedStringResource("prototype.camera.image_playground_unavailable_title")
    static let cameraImagePlaygroundUnavailableBody = LocalizedStringResource("prototype.camera.image_playground_unavailable_body")
    static let cameraAvatarGenerationFailedTitle = LocalizedStringResource("prototype.camera.avatar_generation_failed_title")
    static let cameraAvatarGenerationFailedBody = LocalizedStringResource("prototype.camera.avatar_generation_failed_body")
    static let cameraUnsupportedLanguageBody = LocalizedStringResource("prototype.camera.unsupported_language_body")
    static let cameraForegroundRequiredBody = LocalizedStringResource("prototype.camera.foreground_required_body")
    static let cameraFaceTooSmallBody = LocalizedStringResource("prototype.camera.face_too_small_body")
    static let cameraUnsupportedInputBody = LocalizedStringResource("prototype.camera.unsupported_input_body")
    static let cameraCancelledBody = LocalizedStringResource("prototype.camera.cancelled_body")
    static let cameraPickFailedTitle = LocalizedStringResource("prototype.camera.pick_failed_title")
    static let cameraPickFailedBody = LocalizedStringResource("prototype.camera.pick_failed_body")
    static let cameraFrontCameraPlaceholder = LocalizedStringResource("prototype.camera.front_camera_placeholder")

    static let voiceTitle = LocalizedStringResource("prototype.voice.title")
    static let voiceSubtitle = LocalizedStringResource("prototype.voice.subtitle")
    static let voiceQuote = LocalizedStringResource("prototype.voice.quote")
    static let voiceListening = LocalizedStringResource("prototype.voice.listening")
    static let voicePermissionTitle = LocalizedStringResource("prototype.voice.permission_title")
    static let voicePermissionBody = LocalizedStringResource("prototype.voice.permission_body")
    static let voiceRecordingFailedTitle = LocalizedStringResource("prototype.voice.recording_failed_title")
    static let voiceRecordingFailedBody = LocalizedStringResource("prototype.voice.recording_failed_body")
    static let voiceMissingSampleTitle = LocalizedStringResource("prototype.voice.missing_sample_title")
    static let voiceMissingSampleBody = LocalizedStringResource("prototype.voice.missing_sample_body")
    static let voiceUploading = LocalizedStringResource("prototype.voice.uploading")
    static let voiceQueued = LocalizedStringResource("prototype.voice.queued")
    static let voiceTraining = LocalizedStringResource("prototype.voice.training")
    static let voiceTrainingFailedTitle = LocalizedStringResource("prototype.voice.training_failed_title")
    static let voiceTrainingFailedBody = LocalizedStringResource("prototype.voice.training_failed_body")
    static let voiceTrainingBackendConfigurationBody = LocalizedStringResource("prototype.voice.backend_configuration_body")

    static let successTitle = LocalizedStringResource("prototype.success.title")
    static let successSubtitle = LocalizedStringResource("prototype.success.subtitle")
    static let successOpenMessages = LocalizedStringResource("prototype.success.open_messages")
    static let successShareIDCard = LocalizedStringResource("prototype.success.share_id_card")

    static let messagesTitle = LocalizedStringResource("prototype.messages.title")
    static let messagesSubtitle = LocalizedStringResource("prototype.messages.subtitle")
    static let messagesStatusReady = LocalizedStringResource("prototype.messages.status_ready")
    static let messagesStatusListening = LocalizedStringResource("prototype.messages.status_listening")
    static let messagesStatusResponding = LocalizedStringResource("prototype.messages.status_responding")
    static let messagesHint = LocalizedStringResource("prototype.messages.hint")
    static let messagesStartTalking = LocalizedStringResource("prototype.messages.start_talking")
    static let messagesFinishTurn = LocalizedStringResource("prototype.messages.finish_turn")
    static let messagesEndCall = LocalizedStringResource("prototype.messages.end_call")
    static let messagesMicrophonePermissionTitle = LocalizedStringResource("prototype.messages.microphone_permission_title")
    static let messagesMicrophonePermissionBody = LocalizedStringResource("prototype.messages.microphone_permission_body")
    static let messagesSpeechPermissionTitle = LocalizedStringResource("prototype.messages.speech_permission_title")
    static let messagesSpeechPermissionBody = LocalizedStringResource("prototype.messages.speech_permission_body")
    static let messagesSpeechUnavailableBody = LocalizedStringResource("prototype.messages.speech_unavailable_body")
    static let messagesRecordingFailedTitle = LocalizedStringResource("prototype.messages.recording_failed_title")
    static let messagesRecordingFailedBody = LocalizedStringResource("prototype.messages.recording_failed_body")
    static let messagesTranscriptionFailedBody = LocalizedStringResource("prototype.messages.transcription_failed_body")
    static let messagesBackendFailedTitle = LocalizedStringResource("prototype.messages.backend_failed_title")
    static let messagesBackendFailedBody = LocalizedStringResource("prototype.messages.backend_failed_body")
    static let messagesBackendNotConfiguredBody = LocalizedStringResource("prototype.messages.backend_not_configured_body")

    static let providerSettingsTitle = LocalizedStringResource("prototype.provider.title")
    static let providerSettingsSubtitle = LocalizedStringResource("prototype.provider.subtitle")
    static let providerSettingsAccount = LocalizedStringResource("prototype.provider.account")
    static let providerSettingsSignedInAs = LocalizedStringResource("prototype.provider.signed_in_as")
    static let providerSettingsSignedOut = LocalizedStringResource("prototype.provider.signed_out")
    static let providerSettingsEndpoint = LocalizedStringResource("prototype.provider.endpoint")
    static let providerSettingsModel = LocalizedStringResource("prototype.provider.model")
    static let providerSettingsToken = LocalizedStringResource("prototype.provider.token")
    static let providerSettingsLabel = LocalizedStringResource("prototype.provider.label")
    static let providerSettingsSave = LocalizedStringResource("prototype.provider.save")
    static let providerSettingsSaved = LocalizedStringResource("prototype.provider.saved")
    static let providerSettingsSignOut = LocalizedStringResource("prototype.provider.sign_out")
    static let providerSettingsSignedOutStatus = LocalizedStringResource("prototype.provider.signed_out_status")
    static let providerSettingsLoadFailedTitle = LocalizedStringResource("prototype.provider.load_failed_title")
    static let providerSettingsLoadFailedBody = LocalizedStringResource("prototype.provider.load_failed_body")
    static let providerSettingsSaveFailedTitle = LocalizedStringResource("prototype.provider.save_failed_title")
    static let providerSettingsSaveFailedBody = LocalizedStringResource("prototype.provider.save_failed_body")
    static let providerSettingsSignOutFailedTitle = LocalizedStringResource("prototype.provider.sign_out_failed_title")
    static let providerSettingsSignOutFailedBody = LocalizedStringResource("prototype.provider.sign_out_failed_body")
    static let providerSettingsOpen = LocalizedStringResource("prototype.provider.open")

    static let identityBornOnPika = LocalizedStringResource("prototype.identity.born_on_pika")
    static let identityBirthDate = LocalizedStringResource("prototype.identity.birth_date")
    static let identityProfile = LocalizedStringResource("prototype.identity.profile")
    static let identityLocation = LocalizedStringResource("prototype.identity.location")
    static let identityLocationValue = LocalizedStringResource("prototype.identity.location_value")
    static let identityStatus = LocalizedStringResource("prototype.identity.status")
    static let identityStatusValue = LocalizedStringResource("prototype.identity.status_value")
    static let identityFindMeOn = LocalizedStringResource("prototype.identity.find_me_on")
    static let identityProfileLink = LocalizedStringResource("prototype.identity.profile_link")
    static let identityIdentifierLabel = LocalizedStringResource("prototype.identity.identifier_label")
}

/// Presentation model for the generated AI-self ID card.
struct PrototypeIdentityCard {
    let name = "SEMI"
    let birthLabel = AppStrings.identityBornOnPika
    let birthDate = AppStrings.identityBirthDate
    let location = AppStrings.identityLocationValue
    let status = AppStrings.identityStatusValue
    let profileLink = AppStrings.identityProfileLink
    let identifier = "SEMI // 01"
    var avatarImage: UIImage?
}

/// Lightweight persisted onboarding state used to resume the prototype flow.
struct PrototypeSessionState {
    let hasPersistedAccount: Bool
    let voiceProfileID: String?
    let phoneNumber: String
}

/// Stores non-sensitive prototype progress in `UserDefaults`.
@MainActor
final class PrototypeSessionStore {
    static let shared = PrototypeSessionStore()

    private enum Keys {
        static let hasPersistedAccount = "prototype.session.hasPersistedAccount"
        static let voiceProfileID = "prototype.session.voiceProfileID"
        static let phoneNumber = "prototype.session.phoneNumber"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var state: PrototypeSessionState {
        PrototypeSessionState(
            hasPersistedAccount: defaults.bool(forKey: Keys.hasPersistedAccount),
            voiceProfileID: defaults.string(forKey: Keys.voiceProfileID),
            phoneNumber: defaults.string(forKey: Keys.phoneNumber) ?? ""
        )
    }

    func persistAccount(phoneNumber: String) {
        defaults.set(true, forKey: Keys.hasPersistedAccount)
        defaults.set(phoneNumber, forKey: Keys.phoneNumber)
    }

    func saveVoiceProfileID(_ profileID: String?) {
        let trimmedProfileID = profileID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedProfileID, !trimmedProfileID.isEmpty {
            defaults.set(trimmedProfileID, forKey: Keys.voiceProfileID)
        } else {
            defaults.removeObject(forKey: Keys.voiceProfileID)
        }
    }
}

/// Authenticated user payload returned by the backend.
struct PrototypeAuthenticatedUser: Codable, Equatable {
    let userID: String
    let email: String
    let displayName: String
    let photoURL: URL?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case email
        case displayName
        case photoURL = "photoURL"
    }
}

/// Backend session persisted after successful Google sign-in.
struct PrototypeAppSession: Codable, Equatable {
    let sessionToken: String
    let user: PrototypeAuthenticatedUser
}

/// Snapshot wrapper for the current authenticated app session.
struct PrototypeAppSessionState {
    let session: PrototypeAppSession?

    var hasActiveSession: Bool {
        session != nil
    }
}

/// Keychain-backed store for authenticated backend sessions.
@MainActor
final class PrototypeAppSessionStore {
    static let shared = PrototypeAppSessionStore()

    private enum Constants {
        static let service = "com.openclaw.pikatakehome.auth"
        static let account = "current-session"
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var state: PrototypeAppSessionState {
        PrototypeAppSessionState(session: loadCurrentSession())
    }

    func save(_ session: PrototypeAppSession) {
        guard let data = try? encoder.encode(session) else { return }
        KeychainSessionVault.save(data, service: Constants.service, account: Constants.account)
    }

    func clear() {
        KeychainSessionVault.delete(service: Constants.service, account: Constants.account)
    }

    private func loadCurrentSession() -> PrototypeAppSession? {
        guard let data = KeychainSessionVault.load(service: Constants.service, account: Constants.account) else {
            return nil
        }
        return try? decoder.decode(PrototypeAppSession.self, from: data)
    }
}

/// Resolves backend authentication URLs from environment, simulator defaults, or Info.plist.
struct AuthBackendConfiguration {
    let baseURL: URL
    let callbackScheme: String

    private static let simulatorDefaultBaseURL = URL(string: "http://127.0.0.1:8080")!

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AuthBackendConfiguration? {
        let callbackScheme = processInfo.environment["AUTH_REDIRECT_SCHEME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (bundle.object(forInfoDictionaryKey: "AuthRedirectScheme") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "pikatakehome"

        let environmentValue = processInfo.environment["AUTH_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue, !environmentValue.isEmpty, let url = URL(string: environmentValue) {
            return AuthBackendConfiguration(baseURL: url, callbackScheme: callbackScheme)
        }

        let plistAuthValue = (bundle.object(forInfoDictionaryKey: "AuthBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistAuthValue, !plistAuthValue.isEmpty, let url = URL(string: plistAuthValue) {
            return AuthBackendConfiguration(baseURL: url, callbackScheme: callbackScheme)
        }

        let plistChatValue = (bundle.object(forInfoDictionaryKey: "VoiceChatBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistChatValue, !plistChatValue.isEmpty, let url = URL(string: plistChatValue) {
            return AuthBackendConfiguration(baseURL: url, callbackScheme: callbackScheme)
        }

        #if targetEnvironment(simulator)
        return AuthBackendConfiguration(baseURL: simulatorDefaultBaseURL, callbackScheme: callbackScheme)
        #else
        return nil
        #endif
    }

    var sessionURL: URL {
        baseURL.appendingPathComponent("auth/session")
    }

    func googleStartURL(mobileCallbackURL: URL) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/google/start"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "mobile_callback", value: mobileCallbackURL.absoluteString)
        ]
        return components.url!
    }
}

enum PrototypeGoogleAuthError: LocalizedError {
    case backendNotConfigured
    case invalidCallback
    case cancelled
    case backend(message: String)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return String(localized: AppStrings.welcomeGoogleUnavailable)
        case .invalidCallback:
            return String(localized: AppStrings.welcomeGoogleAuthFailed)
        case .cancelled:
            return nil
        case let .backend(message):
            return message
        }
    }
}

@MainActor
/// Service boundary for Google sign-in.
protocol PrototypeGoogleAuthenticating {
    func signInWithGoogle() async throws -> PrototypeAppSession
    func signOut(sessionToken: String) async
}

@MainActor
final class PrototypeGoogleOAuthService: NSObject, PrototypeGoogleAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private let configuration: AuthBackendConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(configuration: AuthBackendConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func signInWithGoogle() async throws -> PrototypeAppSession {
        let callbackURL = URL(string: "\(configuration.callbackScheme)://auth/google")!
        let authStartURL = configuration.googleStartURL(mobileCallbackURL: callbackURL)
        let redirectURL = try await authenticate(at: authStartURL)

        if let error = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "error_description" })?
            .value {
            throw PrototypeGoogleAuthError.backend(message: error)
        }

        if let error = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "error" })?
            .value {
            throw PrototypeGoogleAuthError.backend(message: error)
        }

        guard let sessionToken = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "session_token" })?
            .value,
              !sessionToken.isEmpty
        else {
            throw PrototypeGoogleAuthError.invalidCallback
        }

        var request = URLRequest(url: configuration.sessionURL)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let backendSession = try decoder.decode(BackendSessionResponse.self, from: data)
        return PrototypeAppSession(
            sessionToken: backendSession.sessionToken,
            user: PrototypeAuthenticatedUser(
                userID: backendSession.user.userID,
                email: backendSession.user.email,
                displayName: backendSession.user.displayName,
                photoURL: backendSession.user.photoURL
            )
        )
    }

    func signOut(sessionToken: String) async {
        var request = URLRequest(url: configuration.sessionURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: configuration.callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let sessionError = error as? ASWebAuthenticationSessionError,
                   sessionError.code == .canceledLogin {
                    continuation.resume(throwing: PrototypeGoogleAuthError.cancelled)
                    return
                }

                continuation.resume(throwing: error ?? PrototypeGoogleAuthError.invalidCallback)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            authSession.start()
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrototypeGoogleAuthError.invalidCallback
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? decoder.decode(BackendErrorResponse.self, from: data))?.message
            throw PrototypeGoogleAuthError.backend(
                message: backendMessage ?? String(localized: AppStrings.welcomeGoogleAuthFailed)
            )
        }
    }
}

/// Builds the production Google auth service when backend configuration is available.
enum PrototypeGoogleAuthServiceFactory {
    @MainActor
    static func makeDefault() -> PrototypeGoogleAuthenticating? {
        guard let configuration = AuthBackendConfiguration.load() else {
            return nil
        }

        return PrototypeGoogleOAuthService(configuration: configuration)
    }
}

private struct BackendSessionResponse: Decodable {
    let sessionToken: String
    let user: BackendAuthenticatedUser
}

private struct BackendAuthenticatedUser: Decodable {
    let userID: String
    let email: String
    let displayName: String
    let photoURL: URL?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case email
        case displayName
        case photoURL = "photoURL"
    }
}

private struct BackendErrorResponse: Decodable {
    let message: String
}

private enum KeychainSessionVault {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
