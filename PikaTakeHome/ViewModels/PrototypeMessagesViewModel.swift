//
//  PrototypeMessagesViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

@preconcurrency import AVFAudio
import Foundation
import SwiftUI
import UIKit

/// Current interaction state for the voice-chat screen.
enum PrototypeMessagesCallState: Equatable {
    case idle
    case listening
    case responding
}

/// Single rendered message in the chat transcript.
struct PrototypeVoiceChatMessage: Identifiable, Equatable {
    enum Speaker: Equatable {
        case semi
        case user
    }

    let id = UUID()
    let speaker: Speaker
    let text: String
}

/// Errors raised while recording a turn or sending it to the chat backend.
enum MessagesVoiceChatError: LocalizedError {
    case microphonePermissionDenied
    case failedToStartRecording
    case failedToStopRecording
    case backendNotConfigured
    case voiceProfileRequired
    case textOnlyResponse
    case backendNetworkFailed(message: String)
    case invalidResponse
    case backendFailed(message: String)

    var title: String {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: AppStrings.messagesMicrophonePermissionTitle)
        case .failedToStartRecording, .failedToStopRecording:
            return String(localized: AppStrings.messagesRecordingFailedTitle)
        case .backendNotConfigured, .backendNetworkFailed, .invalidResponse, .backendFailed:
            return String(localized: AppStrings.messagesBackendFailedTitle)
        case .voiceProfileRequired:
            return String(localized: AppStrings.messagesVoiceProfileRequiredTitle)
        case .textOnlyResponse:
            return String(localized: AppStrings.messagesTextOnlyTitle)
        }
    }

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: AppStrings.messagesMicrophonePermissionBody)
        case .failedToStartRecording, .failedToStopRecording:
            return String(localized: AppStrings.messagesRecordingFailedBody)
        case .backendNotConfigured:
            return String(localized: AppStrings.messagesBackendNotConfiguredBody)
        case .voiceProfileRequired:
            return String(localized: AppStrings.messagesVoiceProfileRequiredBody)
        case .textOnlyResponse:
            return String(localized: AppStrings.messagesTextOnlyBody)
        case let .backendNetworkFailed(message):
            return message
        case .invalidResponse:
            return String(localized: AppStrings.messagesBackendFailedBody)
        case let .backendFailed(message):
            return message
        }
    }
}

/// File-backed voice turn captured from the user.
struct MessagesRecordedTurn {
    let fileURL: URL
    let duration: TimeInterval

    var mimeType: String {
        switch fileURL.pathExtension.lowercased() {
        case "wav":
            return "audio/wav"
        case "caf":
            return "audio/x-caf"
        default:
            return "application/octet-stream"
        }
    }
}

/// Recorder abstraction used by the messages screen.
protocol MessagesVoiceRecorder {
    func start() async throws
    func stop() async throws -> MessagesRecordedTurn
    func cancel() async
}

/// Resolves the voice-chat backend URL from environment, simulator defaults, or Info.plist.
struct VoiceChatBackendConfiguration {
    let baseURL: URL
    private static let simulatorDefaultBaseURL = URL(string: "http://127.0.0.1:8080")!

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> VoiceChatBackendConfiguration? {
        let environmentValue = processInfo.environment["VOICE_CHAT_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue, !environmentValue.isEmpty, let url = URL(string: environmentValue) {
            return VoiceChatBackendConfiguration(baseURL: url)
        }

        let plistValue = (bundle.object(forInfoDictionaryKey: "VoiceChatBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistValue, !plistValue.isEmpty, let url = URL(string: plistValue) {
            return VoiceChatBackendConfiguration(baseURL: url)
        }

        #if targetEnvironment(simulator)
        return VoiceChatBackendConfiguration(baseURL: simulatorDefaultBaseURL)
        #else
        return nil
        #endif
    }

    var turnURL: URL {
        baseURL.appendingPathComponent("voice-chat").appendingPathComponent("turn")
    }

    var voiceJobsURL: URL {
        baseURL.appendingPathComponent("voice-chat").appendingPathComponent("jobs")
    }

    func voiceJobStatusURL(jobID: String) -> URL {
        voiceJobsURL.appendingPathComponent(jobID)
    }
}

private struct MessagesBackendHistoryMessage: Encodable {
    let role: String
    let content: String
}

private struct MessagesBackendTurnRequest: Encodable {
    let audioBase64: String?
    let audioChunks: [AudioUploadChunk]?
    let mimeType: String
    let fileName: String
    let durationSeconds: TimeInterval
    let voiceProfileID: String?
    let conversationSummary: String?
    let history: [MessagesBackendHistoryMessage]
}

private struct MessagesBackendTurnResponse: Decodable {
    let transcript: String
    let responseText: String
    let responseAudioBase64: String?
    let responseAudioMimeType: String?
    let error: String?
}

private struct MessagesBackendVoiceJobSubmitResponse: Decodable {
    let jobID: String
    let stage: String

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case stage
    }
}

private struct MessagesBackendVoiceJobStatusResponse: Decodable {
    let jobID: String
    let stage: String
    let transcript: String?
    let responseText: String?
    let responseAudioBase64: String?
    let responseAudioMimeType: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case stage
        case transcript
        case responseText
        case responseAudioBase64
        case responseAudioMimeType
        case error
    }
}

/// Decoded backend result for a single conversational turn.
struct MessagesTurnResult {
    let transcript: String
    let responseText: String
    let responseAudioData: Data?
}

/// Persisted conversation state used to restore chat history between launches.
struct MessagesConversationSnapshot {
    let summary: String
    let voiceProfileID: String?
    let avatarImage: UIImage?
    let messages: [PrototypeVoiceChatMessage]
}

protocol MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult
}

protocol MessagesConversationPersisting {
    func loadConversation() async throws -> MessagesConversationSnapshot
    func saveConversation(
        summary: String,
        voiceProfileID: String?,
        avatarImage: UIImage?,
        messages: [PrototypeVoiceChatMessage]
    ) async throws
}

@MainActor
protocol MessagesAudioPlaying: AnyObject {
    func play(_ audioData: Data) throws
    func stop()
}

/// `AVAudioRecorder` backed recorder for chat turns.
final class MessagesAudioRecorder: NSObject, MessagesVoiceRecorder, @unchecked Sendable {
    private var recorder: AVAudioRecorder?

    func start() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .denied:
            throw MessagesVoiceChatError.microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else {
                throw MessagesVoiceChatError.microphonePermissionDenied
            }
        @unknown default:
            throw MessagesVoiceChatError.microphonePermissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-messages-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        // Whisper resamples input to 16 kHz internally, and the backend simply
        // forwards the recorded audio, so recording at the ASR's native rate
        // keeps transcription quality while cutting the upload payload ~2.75x.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw MessagesVoiceChatError.failedToStartRecording
        }

        self.recorder = recorder
    }

    func stop() async throws -> MessagesRecordedTurn {
        guard let recorder else {
            throw MessagesVoiceChatError.failedToStopRecording
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard duration > 0 else {
            throw MessagesVoiceChatError.failedToStopRecording
        }

        return MessagesRecordedTurn(fileURL: recorder.url, duration: duration)
    }

    func cancel() async {
        if let recorder {
            recorder.stop()
            recorder.deleteRecording()
        }
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// HTTP client that sends recorded turns to the voice-chat backend.
actor HTTPMessagesVoiceChatService: MessagesVoiceChatResponding {
    private static let maxHistoryMessages = 8
    private static let requestTimeout: TimeInterval = 180
    private static let pollInterval: TimeInterval = 1.0

    private let configuration: VoiceChatBackendConfiguration
    private let sessionToken: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: VoiceChatBackendConfiguration,
        sessionToken: String? = nil,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionToken = sessionToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        self.session = session
    }

    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        let audioChunks = try AudioChunker.chunkedUploads(for: recordedTurn.fileURL, duration: recordedTurn.duration)
        let shouldChunk = !audioChunks.isEmpty
        let audioBase64 = shouldChunk ? nil : try Data(contentsOf: recordedTurn.fileURL).base64EncodedString()
        let trimmedHistory = history.suffix(Self.maxHistoryMessages)
        let requestBody = MessagesBackendTurnRequest(
            audioBase64: audioBase64,
            audioChunks: shouldChunk ? audioChunks : nil,
            mimeType: recordedTurn.mimeType,
            fileName: recordedTurn.fileURL.lastPathComponent,
            durationSeconds: recordedTurn.duration,
            voiceProfileID: voiceProfileID,
            conversationSummary: conversationSummary?.nilIfBlank,
            history: trimmedHistory.map {
                MessagesBackendHistoryMessage(
                    role: $0.speaker == .user ? "user" : "assistant",
                    content: $0.text
                )
            }
        )

        var request = URLRequest(url: configuration.voiceJobsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try encoder.encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw MessagesVoiceChatError.backendNetworkFailed(
                message: Self.networkFailureMessage(for: error, baseURL: configuration.baseURL)
            )
        }
        try validate(response: response, data: data)

        let accepted = try decoder.decode(MessagesBackendVoiceJobSubmitResponse.self, from: data)
        return try await pollForCompletedJob(jobID: accepted.jobID)
    }

    private static func networkFailureMessage(for error: URLError, baseURL: URL) -> String {
        switch error.code {
        case .timedOut:
            return "The voice backend took longer than \(Int(requestTimeout)) seconds to answer at \(baseURL.absoluteString). Try a shorter recording, or wait for the local models to warm up and try again."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet, .networkConnectionLost:
            return "The app could not reach the voice backend at \(baseURL.absoluteString). Make sure the phone is on the same Wi-Fi and the backend is still running."
        default:
            return "The app could not complete the voice request at \(baseURL.absoluteString): \(error.localizedDescription)"
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendError = (try? decoder.decode(MessagesBackendErrorResponse.self, from: data))?.message
                ?? (try? decoder.decode(MessagesBackendTurnResponse.self, from: data))?.error
            throw MessagesVoiceChatError.backendFailed(
                message: backendError ?? String(localized: AppStrings.messagesBackendFailedBody)
            )
        }
    }

    private func pollForCompletedJob(jobID: String) async throws -> MessagesTurnResult {
        let deadline = Date().addingTimeInterval(Self.requestTimeout)

        while Date() < deadline {
            var request = URLRequest(url: configuration.voiceJobStatusURL(jobID: jobID))
            request.httpMethod = "GET"
            request.timeoutInterval = min(30, Self.requestTimeout)
            if let sessionToken {
                request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError {
                throw MessagesVoiceChatError.backendNetworkFailed(
                    message: Self.networkFailureMessage(for: error, baseURL: configuration.baseURL)
                )
            }
            try validate(response: response, data: data)

            let decoded = try decoder.decode(MessagesBackendVoiceJobStatusResponse.self, from: data)
            switch decoded.stage {
            case "queued", "transcribing", "generating", "synthesizing":
                try await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
            case "failed":
                throw MessagesVoiceChatError.backendFailed(
                    message: decoded.error ?? String(localized: AppStrings.messagesBackendFailedBody)
                )
            case "ready":
                let transcript = decoded.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let responseText = decoded.responseText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !transcript.isEmpty, !responseText.isEmpty else {
                    throw MessagesVoiceChatError.invalidResponse
                }
                let responseAudioData = decoded.responseAudioBase64.flatMap { Data(base64Encoded: $0) }
                return MessagesTurnResult(
                    transcript: transcript,
                    responseText: responseText,
                    responseAudioData: responseAudioData
                )
            default:
                throw MessagesVoiceChatError.invalidResponse
            }
        }

        throw MessagesVoiceChatError.backendFailed(
            message: "The voice backend did not finish the queued job within \(Int(Self.requestTimeout)) seconds."
        )
    }
}

/// Failing chat service used when no backend URL is configured.
actor UnconfiguredMessagesVoiceChatService: MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        throw MessagesVoiceChatError.backendNotConfigured
    }
}

private struct MessagesConversationBackendMessage: Codable {
    let role: String
    let content: String
}

private struct MessagesConversationResponse: Decodable {
    let conversationID: String
    let summary: String
    let voiceProfileID: String?
    let avatarBase64: String?
    let messages: [MessagesConversationBackendMessage]

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversationId"
        case summary
        case voiceProfileID = "voiceProfileID"
        case avatarBase64 = "avatarBase64"
        case messages
    }
}

private struct MessagesConversationRequest: Encodable {
    let summary: String
    let voiceProfileID: String?
    let avatarBase64: String?
    let messages: [MessagesConversationBackendMessage]
}

private struct MessagesBackendErrorResponse: Decodable {
    let message: String
}

/// Persists conversation summaries and history through the backend.
actor HTTPMessagesConversationService: MessagesConversationPersisting {
    private let url: URL
    private let sessionToken: String
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL, sessionToken: String, session: URLSession = .shared) {
        self.url = url
        self.sessionToken = sessionToken
        self.session = session
    }

    func loadConversation() async throws -> MessagesConversationSnapshot {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(MessagesConversationResponse.self, from: data)
        return MessagesConversationSnapshot(
            summary: decoded.summary,
            voiceProfileID: decoded.voiceProfileID,
            avatarImage: Self.decodeAvatarImage(from: decoded.avatarBase64),
            messages: decoded.messages.compactMap(Self.mapMessage)
        )
    }

    func saveConversation(
        summary: String,
        voiceProfileID: String?,
        avatarImage: UIImage?,
        messages: [PrototypeVoiceChatMessage]
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            MessagesConversationRequest(
                summary: summary,
                voiceProfileID: voiceProfileID,
                avatarBase64: Self.encodeAvatarImage(avatarImage),
                messages: messages.map {
                    MessagesConversationBackendMessage(
                        role: $0.speaker == .user ? "user" : "assistant",
                        content: $0.text
                    )
                }
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? decoder.decode(MessagesBackendErrorResponse.self, from: data))?.message
            throw MessagesVoiceChatError.backendFailed(
                message: backendMessage ?? String(localized: AppStrings.messagesBackendFailedBody)
            )
        }
    }

    private static func mapMessage(_ message: MessagesConversationBackendMessage) -> PrototypeVoiceChatMessage? {
        let normalizedRole = message.role.lowercased()
        let speaker: PrototypeVoiceChatMessage.Speaker
        switch normalizedRole {
        case "user":
            speaker = .user
        case "assistant":
            speaker = .semi
        default:
            return nil
        }

        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }
        return PrototypeVoiceChatMessage(speaker: speaker, text: trimmedContent)
    }

    private static func decodeAvatarImage(from base64: String?) -> UIImage? {
        guard let base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private static func encodeAvatarImage(_ image: UIImage?) -> String? {
        guard let image else { return nil }
        return image
            .resizedForConversationAvatar(maxDimension: 512)?
            .jpegData(compressionQuality: 0.82)?
            .base64EncodedString()
    }
}

/// Builds the chat service from the configured backend URL and active session.
enum MessagesVoiceChatServiceFactory {
    @MainActor
    static func makeDefault(
        appSessionStore: PrototypeAppSessionStore? = nil
    ) -> MessagesVoiceChatResponding {
        let sessionToken = (appSessionStore ?? .shared).state.session?.sessionToken
        if let configuration = VoiceChatBackendConfiguration.load() {
            return HTTPMessagesVoiceChatService(
                configuration: configuration,
                sessionToken: sessionToken
            )
        }

        return UnconfiguredMessagesVoiceChatService()
    }
}

/// Builds the conversation persistence service from auth configuration.
enum MessagesConversationServiceFactory {
    @MainActor
    static func makeDefault(
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load(),
        appSessionStore: PrototypeAppSessionStore? = nil
    ) -> MessagesConversationPersisting? {
        let appSessionStore = appSessionStore ?? .shared
        guard
            let authConfiguration,
            let sessionToken = appSessionStore.state.session?.sessionToken,
            !sessionToken.isEmpty
        else {
            return nil
        }

        return HTTPMessagesConversationService(
            url: authConfiguration.baseURL.appendingPathComponent("conversations").appendingPathComponent("default"),
            sessionToken: sessionToken
        )
    }
}

@MainActor
/// Small `AVAudioPlayer` wrapper for backend response audio.
final class MessagesAudioPlayer: NSObject, MessagesAudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(_ audioData: Data) throws {
        stop()
        let player = try AVAudioPlayer(data: audioData)
        player.prepareToPlay()
        player.delegate = self
        guard player.play() else {
            throw MessagesVoiceChatError.invalidResponse
        }
        self.player = player
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

@MainActor
/// View model for the voice-chat conversation experience.
final class PrototypeMessagesViewModel: ObservableObject {
    private static let recentContextMessages = 8
    private static let summaryMaxCharacters = 1_200
    private static let summaryEntryMaxCharacters = 140
    private static let initialMessages = [
        PrototypeVoiceChatMessage(
            speaker: .semi,
            text: "I am here. Talk to me like you would talk to your future self."
        )
    ]

    @Published private(set) var avatarImage: UIImage?
    @Published private(set) var callState: PrototypeMessagesCallState = .idle
    @Published private(set) var statusText = String(localized: AppStrings.messagesStatusReady)
    @Published private(set) var messages: [PrototypeVoiceChatMessage] = PrototypeMessagesViewModel.initialMessages
    @Published var alert: PrototypeCameraAlert?

    var onBackRequested: (() -> Void)?
    var onOpenProviderSettingsRequested: (() -> Void)?
    var onRetrainVoiceRequested: (() -> Void)?
    var onUpdateAvatarRequested: (() -> Void)?

    private let recorder: MessagesVoiceRecorder
    private let chatService: MessagesVoiceChatResponding
    private let conversationStore: MessagesConversationPersisting?
    private let audioPlayer: MessagesAudioPlaying
    private let featureFlags: FeatureFlagManaging
    private let isBackendConfigured: Bool
    private var voiceProfileID: String?
    private var conversationSummary = ""
    private var hasLoadedPersistedConversation = false

    let title = AppStrings.messagesTitle
    let subtitle = AppStrings.messagesSubtitle
    let hint = AppStrings.messagesHint

    init(
        recorder: MessagesVoiceRecorder? = nil,
        chatService: MessagesVoiceChatResponding? = nil,
        conversationStore: MessagesConversationPersisting? = nil,
        audioPlayer: MessagesAudioPlaying? = nil,
        featureFlags: FeatureFlagManaging = FeatureFlagManager.shared
    ) {
        let isVoiceChatEnabled = featureFlags.isEnabled(.enableVoiceChat)
        let resolvedChatService = chatService ?? MessagesVoiceChatServiceFactory.makeDefault()
        self.recorder = recorder ?? MessagesAudioRecorder()
        self.chatService = resolvedChatService
        self.conversationStore = isVoiceChatEnabled
            ? (conversationStore ?? MessagesConversationServiceFactory.makeDefault())
            : nil
        self.audioPlayer = audioPlayer ?? MessagesAudioPlayer()
        self.featureFlags = featureFlags
        self.isBackendConfigured = !(resolvedChatService is UnconfiguredMessagesVoiceChatService)
    }

    func setAvatarImage(_ image: UIImage?) {
        avatarImage = image
    }

    func setVoiceProfileID(_ profileID: String?) {
        voiceProfileID = profileID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        Task {
            await persistConversationIfPossible()
        }
    }

    func saveConversationNow() async {
        await persistConversationIfPossible()
    }

    func reset() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        avatarImage = nil
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        messages = PrototypeMessagesViewModel.initialMessages
        alert = nil
        voiceProfileID = nil
        conversationSummary = ""
        hasLoadedPersistedConversation = false
    }

    func backTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onBackRequested?()
    }

    func primaryActionTapped() {
        switch callState {
        case .idle:
            guard !featureFlags.isEnabled(.enableVoiceChat) || isBackendConfigured else {
                presentAlert(for: .backendNotConfigured)
                return
            }
            guard !featureFlags.isEnabled(.enableVoiceChat) || voiceProfileID?.nilIfBlank != nil else {
                presentAlert(for: .voiceProfileRequired)
                return
            }
            Task {
                await startListening()
            }
        case .listening:
            Task {
                await finishUserTurn()
            }
        case .responding:
            break
        }
    }

    func endCallTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
    }

    func retrainVoiceTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onRetrainVoiceRequested?()
    }

    func updateAvatarTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onUpdateAvatarRequested?()
    }

    func openProviderSettingsTapped() {
        onOpenProviderSettingsRequested?()
    }

    var primaryButtonTitle: LocalizedStringResource {
        switch callState {
        case .idle, .responding:
            return AppStrings.messagesStartTalking
        case .listening:
            return AppStrings.messagesFinishTurn
        }
    }

    var isPrimaryButtonEnabled: Bool {
        callState != .responding
    }

    var showsProviderSettingsButton: Bool {
        featureFlags.isEnabled(.enableVoiceChat)
    }

    var showsRetrainVoiceButton: Bool {
        featureFlags.isEnabled(.enableVoiceTraining)
    }

    func prepareConversation() async {
        guard !hasLoadedPersistedConversation else { return }
        hasLoadedPersistedConversation = true
        guard let conversationStore else { return }
        let preferredVoiceProfileID = voiceProfileID?.nilIfBlank
        let preferredAvatarImage = avatarImage

        do {
            let snapshot = try await conversationStore.loadConversation()
            let storedVoiceProfileID = snapshot.voiceProfileID?.nilIfBlank
            if snapshot.messages.isEmpty {
                messages = PrototypeMessagesViewModel.initialMessages
                conversationSummary = snapshot.summary
            } else {
                messages = snapshot.messages
                conversationSummary = snapshot.summary
            }

            let resolvedVoiceProfileID = preferredVoiceProfileID ?? storedVoiceProfileID
            voiceProfileID = resolvedVoiceProfileID
            avatarImage = preferredAvatarImage ?? snapshot.avatarImage
            if preferredVoiceProfileID != nil, preferredVoiceProfileID != storedVoiceProfileID {
                await persistConversationIfPossible()
            } else if preferredAvatarImage != nil, snapshot.avatarImage == nil {
                await persistConversationIfPossible()
            }
        } catch {
            // Keep the current in-memory conversation when sync fails.
        }
    }

    private func startListening() async {
        alert = nil

        do {
            try await recorder.start()
            callState = .listening
            statusText = String(localized: AppStrings.messagesStatusListening)
        } catch let error as MessagesVoiceChatError {
            presentAlert(for: error)
        } catch {
            presentAlert(for: .failedToStartRecording)
        }
    }

    private func finishUserTurn() async {
        do {
            let recordedTurn = try await recorder.stop()
            callState = .responding
            statusText = String(localized: AppStrings.messagesStatusResponding)

            guard featureFlags.isEnabled(.enableVoiceChat) else {
                appendLocalDemoTurn(recordedTurn)
                callState = .idle
                statusText = String(localized: AppStrings.messagesStatusReady)
                return
            }

            let result = try await chatService.respond(
                to: recordedTurn,
                history: messages,
                conversationSummary: conversationSummary,
                voiceProfileID: voiceProfileID
            )
            messages.append(PrototypeVoiceChatMessage(speaker: .user, text: result.transcript))
            messages.append(PrototypeVoiceChatMessage(speaker: .semi, text: result.responseText))
            rebuildConversationSummary()
            await persistConversationIfPossible()

            if let responseAudioData = result.responseAudioData {
                try audioPlayer.play(responseAudioData)
            } else {
                presentAlert(for: .textOnlyResponse)
            }

            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
        } catch let error as MessagesVoiceChatError {
            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
            presentAlert(for: error)
        } catch {
            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
            presentAlert(for: .backendFailed(message: String(localized: AppStrings.messagesBackendFailedBody)))
        }
    }

    private func appendLocalDemoTurn(_ recordedTurn: MessagesRecordedTurn) {
        messages.append(
            PrototypeVoiceChatMessage(
                speaker: .user,
                text: "Voice note recorded locally (\(formattedDuration(recordedTurn.duration)))."
            )
        )
        messages.append(
            PrototypeVoiceChatMessage(
                speaker: .semi,
                text: "Voice Chat is disabled, so this UI-only flow is not sending audio to the service yet."
            )
        )
        rebuildConversationSummary()
    }

    private func presentAlert(for error: MessagesVoiceChatError) {
        alert = PrototypeCameraAlert(
            title: error.title,
            message: error.errorDescription ?? String(localized: AppStrings.messagesBackendFailedBody)
        )
    }

    private func rebuildConversationSummary() {
        let archivedMessages = messages.dropLast(Self.recentContextMessages)
        guard !archivedMessages.isEmpty else {
            conversationSummary = ""
            return
        }

        var selectedLines: [String] = []
        var consumedCharacters = 0

        for message in archivedMessages.reversed() {
            let normalizedText = message.text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedText.isEmpty else { continue }

            let truncatedText: String
            if normalizedText.count > Self.summaryEntryMaxCharacters {
                truncatedText = String(normalizedText.prefix(Self.summaryEntryMaxCharacters - 3)) + "..."
            } else {
                truncatedText = normalizedText
            }

            let rolePrefix = message.speaker == .user ? "User" : "SEMI"
            let line = "\(rolePrefix): \(truncatedText)"
            let lineCost = line.count + (selectedLines.isEmpty ? 0 : 1)
            if consumedCharacters + lineCost > Self.summaryMaxCharacters {
                break
            }

            selectedLines.append(line)
            consumedCharacters += lineCost
        }

        conversationSummary = selectedLines.reversed().joined(separator: "\n")
    }

    private func persistConversationIfPossible() async {
        guard let conversationStore else { return }

        do {
            try await conversationStore.saveConversation(
                summary: conversationSummary,
                voiceProfileID: voiceProfileID,
                avatarImage: avatarImage,
                messages: messages
            )
        } catch {
            // Persistence is best-effort so local chat remains usable even if sync fails.
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private extension UIImage {
    func resizedForConversationAvatar(maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
