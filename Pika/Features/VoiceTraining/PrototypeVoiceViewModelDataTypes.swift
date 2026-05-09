//
//  PrototypeVoiceViewModelDataTypes.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation

/// File-backed recording captured during voice onboarding.
struct VoiceRecordedSample {
    let fileURL: URL
    let duration: TimeInterval
}

/// Payload submitted to the backend voice-training endpoint.
struct VoiceTrainingSample {
    let fileURL: URL
    let transcript: String
    let duration: TimeInterval
    let baseProfileID: String?

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

/// Backend voice-training job state.
enum VoiceTrainingJobStatus: Equatable {
    case queued
    case processing(progress: Double?)
    case ready(profileID: String)
    case failed(message: String)
}

/// User-facing recording failures.
enum VoiceRecordingError: LocalizedError {
    case permissionDenied
    case failedToStart
    case failedToFinish
    case missingRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: AppStrings.voicePermissionBody)
        case .failedToStart:
            return String(localized: AppStrings.voiceRecordingFailedBody)
        case .failedToFinish:
            return String(localized: AppStrings.voiceRecordingFailedBody)
        case .missingRecording:
            return String(localized: AppStrings.voiceMissingSampleBody)
        }
    }
}

/// Recorder abstraction used by the voice view model.
protocol VoiceSampleRecording {
    func start() async throws
    func stop() async throws -> VoiceRecordedSample
    func cancel() async
    var currentTime: TimeInterval { get async }
}

/// Backend abstraction for voice-profile training.
protocol VoiceProfileTraining {
    func capabilities() async throws -> VoiceTrainingCapabilities
    func submit(sample: VoiceTrainingSample) async throws -> String
    func status(for jobID: String) async throws -> VoiceTrainingJobStatus
}

/// Capability response describing whether personalized voice training is available.
struct VoiceTrainingCapabilities: Equatable {
    let trainingCommandConfigured: Bool
    let trainingMode: String
    let supportsPersonalizedVoice: Bool
    let message: String?
}

/// Resolves the voice-training backend URL from environment, simulator defaults, or Info.plist.
///
/// Delegates to ``PikaBackendConfiguration`` for unified URL and API-key resolution.
/// The legacy `VOICE_TRAINING_BASE_URL` and `VoiceTrainingBaseURL` values continue to work
/// as fallbacks — new deployments should use `PIKA_BACKEND_BASE_URL`.
struct VoiceTrainingAPIConfiguration {
    let baseURL: URL
    let apiKey: String?

    init(baseURL: URL, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> VoiceTrainingAPIConfiguration? {
        guard let pikaConfig = PikaBackendConfiguration.load(bundle: bundle, processInfo: processInfo) else {
            return nil
        }
        return VoiceTrainingAPIConfiguration(baseURL: pikaConfig.baseURL, apiKey: pikaConfig.apiKey)
    }

    var submitURL: URL {
        baseURL.appendingPathComponent("voice-profiles")
    }

    var capabilitiesURL: URL {
        submitURL.appendingPathComponent("capabilities")
    }

    func statusURL(for jobID: String) -> URL {
        submitURL.appendingPathComponent(jobID)
    }

    func decorate(_ request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
    }
}

enum VoiceTrainingServiceError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case backend(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration, .invalidResponse:
            return String(localized: AppStrings.voiceTrainingFailedBody)
        case let .backend(message):
            return message
        }
    }
}
