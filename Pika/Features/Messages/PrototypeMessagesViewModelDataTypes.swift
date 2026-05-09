//
//  PrototypeMessagesViewModelDataTypes.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

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
            return String(localized: AppStrings.messagesMicrophonePermissionTitle
            )
        case .failedToStartRecording,
                .failedToStopRecording:
            return String(localized: AppStrings.messagesRecordingFailedTitle
            )
        case .backendNotConfigured,
                .backendNetworkFailed,
                .invalidResponse,
                .backendFailed:
            return String(localized: AppStrings
                .messagesBackendFailedTitle
            )
        case .voiceProfileRequired:
            return String(localized: AppStrings.messagesVoiceProfileRequiredTitle
            )
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
///
/// Delegates to ``PikaBackendConfiguration`` for unified URL and API-key resolution.
/// The legacy `VOICE_CHAT_BASE_URL` environment variable and `VoiceChatBaseURL` Info.plist
/// key continue to work as fallbacks — new deployments should use `PIKA_BACKEND_BASE_URL`.
struct VoiceChatBackendConfiguration {
    let baseURL: URL
    let apiKey: String?

    init(baseURL: URL, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> VoiceChatBackendConfiguration? {
        guard let pikaConfig = PikaBackendConfiguration.load(bundle: bundle, processInfo: processInfo) else {
            return nil
        }
        return VoiceChatBackendConfiguration(baseURL: pikaConfig.baseURL, apiKey: pikaConfig.apiKey)
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

    func decorate(_ request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
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
