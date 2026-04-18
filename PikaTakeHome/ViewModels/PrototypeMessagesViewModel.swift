@preconcurrency import AVFAudio
import Foundation
import SwiftUI
import UIKit

enum PrototypeMessagesCallState: Equatable {
    case idle
    case listening
    case responding
}

struct PrototypeVoiceChatMessage: Identifiable, Equatable {
    enum Speaker: Equatable {
        case semi
        case user
    }

    let id = UUID()
    let speaker: Speaker
    let text: String
}

enum MessagesVoiceChatError: LocalizedError {
    case microphonePermissionDenied
    case failedToStartRecording
    case failedToStopRecording
    case backendNotConfigured
    case invalidResponse
    case backendFailed(message: String)

    var title: String {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: AppStrings.messagesMicrophonePermissionTitle)
        case .failedToStartRecording, .failedToStopRecording:
            return String(localized: AppStrings.messagesRecordingFailedTitle)
        case .backendNotConfigured, .invalidResponse, .backendFailed:
            return String(localized: AppStrings.messagesBackendFailedTitle)
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
        case .invalidResponse:
            return String(localized: AppStrings.messagesBackendFailedBody)
        case let .backendFailed(message):
            return message
        }
    }
}

struct MessagesRecordedTurn {
    let fileURL: URL
    let duration: TimeInterval
}

protocol MessagesVoiceRecorder {
    func start() async throws
    func stop() async throws -> MessagesRecordedTurn
    func cancel() async
}

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

        #if targetEnvironment(simulator)
        return VoiceChatBackendConfiguration(baseURL: simulatorDefaultBaseURL)
        #else
        let plistValue = (bundle.object(forInfoDictionaryKey: "VoiceChatBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistValue, !plistValue.isEmpty, let url = URL(string: plistValue) {
            return VoiceChatBackendConfiguration(baseURL: url)
        }
        #endif

        return nil
    }

    var turnURL: URL {
        baseURL.appendingPathComponent("voice-chat").appendingPathComponent("turn")
    }
}

private struct MessagesBackendHistoryMessage: Encodable {
    let role: String
    let content: String
}

private struct MessagesBackendTurnRequest: Encodable {
    let audioBase64: String
    let mimeType: String
    let fileName: String
    let durationSeconds: TimeInterval
    let voiceProfileID: String?
    let history: [MessagesBackendHistoryMessage]
}

private struct MessagesBackendTurnResponse: Decodable {
    let transcript: String
    let responseText: String
    let responseAudioBase64: String?
    let responseAudioMimeType: String?
    let error: String?
}

struct MessagesTurnResult {
    let transcript: String
    let responseText: String
    let responseAudioData: Data?
}

protocol MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult
}

@MainActor
protocol MessagesAudioPlaying: AnyObject {
    func play(_ audioData: Data) throws
    func stop()
}

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
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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

actor HTTPMessagesVoiceChatService: MessagesVoiceChatResponding {
    private let configuration: VoiceChatBackendConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: VoiceChatBackendConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        let audioData = try Data(contentsOf: recordedTurn.fileURL)
        let requestBody = MessagesBackendTurnRequest(
            audioBase64: audioData.base64EncodedString(),
            mimeType: "audio/m4a",
            fileName: recordedTurn.fileURL.lastPathComponent,
            durationSeconds: recordedTurn.duration,
            voiceProfileID: voiceProfileID,
            history: history.map {
                MessagesBackendHistoryMessage(
                    role: $0.speaker == .user ? "user" : "assistant",
                    content: $0.text
                )
            }
        )

        var request = URLRequest(url: configuration.turnURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(MessagesBackendTurnResponse.self, from: data)
        if let error = decoded.error, !error.isEmpty {
            throw MessagesVoiceChatError.backendFailed(message: error)
        }

        let transcript = decoded.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let responseText = decoded.responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty, !responseText.isEmpty else {
            throw MessagesVoiceChatError.invalidResponse
        }

        let responseAudioData = decoded.responseAudioBase64.flatMap { Data(base64Encoded: $0) }
        return MessagesTurnResult(
            transcript: transcript,
            responseText: responseText,
            responseAudioData: responseAudioData
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendError = (try? decoder.decode(MessagesBackendTurnResponse.self, from: data))?.error
            throw MessagesVoiceChatError.backendFailed(
                message: backendError ?? String(localized: AppStrings.messagesBackendFailedBody)
            )
        }
    }
}

actor UnconfiguredMessagesVoiceChatService: MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        throw MessagesVoiceChatError.backendNotConfigured
    }
}

enum MessagesVoiceChatServiceFactory {
    static func makeDefault() -> MessagesVoiceChatResponding {
        if let configuration = VoiceChatBackendConfiguration.load() {
            return HTTPMessagesVoiceChatService(configuration: configuration)
        }

        return UnconfiguredMessagesVoiceChatService()
    }
}

@MainActor
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
final class PrototypeMessagesViewModel: ObservableObject {
    @Published private(set) var avatarImage: UIImage?
    @Published private(set) var callState: PrototypeMessagesCallState = .idle
    @Published private(set) var statusText = String(localized: AppStrings.messagesStatusReady)
    @Published private(set) var messages: [PrototypeVoiceChatMessage] = [
        PrototypeVoiceChatMessage(
            speaker: .semi,
            text: "I am here. Talk to me like you would talk to your future self."
        )
    ]
    @Published var alert: PrototypeCameraAlert?

    var onBackRequested: (() -> Void)?

    private let recorder: MessagesVoiceRecorder
    private let chatService: MessagesVoiceChatResponding
    private let audioPlayer: MessagesAudioPlaying
    private let isBackendConfigured: Bool
    private var voiceProfileID: String?

    let title = AppStrings.messagesTitle
    let subtitle = AppStrings.messagesSubtitle
    let hint = AppStrings.messagesHint

    init(
        recorder: MessagesVoiceRecorder? = nil,
        chatService: MessagesVoiceChatResponding? = nil,
        audioPlayer: MessagesAudioPlaying? = nil
    ) {
        let resolvedChatService = chatService ?? MessagesVoiceChatServiceFactory.makeDefault()
        self.recorder = recorder ?? MessagesAudioRecorder()
        self.chatService = resolvedChatService
        self.audioPlayer = audioPlayer ?? MessagesAudioPlayer()
        self.isBackendConfigured = !(resolvedChatService is UnconfiguredMessagesVoiceChatService)
    }

    func setAvatarImage(_ image: UIImage?) {
        avatarImage = image
    }

    func setVoiceProfileID(_ profileID: String?) {
        voiceProfileID = profileID
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
            guard isBackendConfigured else {
                presentAlert(for: .backendNotConfigured)
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

            let result = try await chatService.respond(
                to: recordedTurn,
                history: messages,
                voiceProfileID: voiceProfileID
            )
            messages.append(PrototypeVoiceChatMessage(speaker: .user, text: result.transcript))
            messages.append(PrototypeVoiceChatMessage(speaker: .semi, text: result.responseText))

            if let responseAudioData = result.responseAudioData {
                try audioPlayer.play(responseAudioData)
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

    private func presentAlert(for error: MessagesVoiceChatError) {
        alert = PrototypeCameraAlert(
            title: error.title,
            message: error.errorDescription ?? String(localized: AppStrings.messagesBackendFailedBody)
        )
    }
}
