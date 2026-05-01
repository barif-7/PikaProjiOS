//
//  PrototypeVoiceViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

@preconcurrency import AVFAudio
import Foundation
import SwiftUI
import UIKit

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

private struct VoiceTrainingBackendErrorResponse: Decodable {
    let message: String?
    let error: String?
    let detail: String?
}

private struct VoiceTrainingSubmitRequest: Encodable {
    let transcript: String
    let durationSeconds: TimeInterval
    let fileName: String
    let mimeType: String
    let audioBase64: String?
    let audioChunks: [AudioUploadChunk]?
    let baseProfileID: String?
}

private struct VoiceTrainingSubmitResponse: Decodable {
    let jobID: String
    let profileID: String?

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case profileID = "profileId"
    }
}

private struct VoiceTrainingStatusResponse: Decodable {
    let status: String
    let progress: Double?
    let profileID: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case progress
        case profileID = "profileId"
        case message
    }
}

private struct VoiceTrainingCapabilitiesResponse: Decodable {
    let trainingCommandConfigured: Bool
    let trainingMode: String
    let supportsPersonalizedVoice: Bool
    let message: String?
}

/// HTTP implementation for voice-profile training.
actor HTTPVoiceProfileTrainingService: VoiceProfileTraining {
    private let configuration: VoiceTrainingAPIConfiguration
    private let sessionToken: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: VoiceTrainingAPIConfiguration,
        sessionToken: String? = nil,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionToken = sessionToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        self.session = session
    }

    func capabilities() async throws -> VoiceTrainingCapabilities {
        var request = URLRequest(url: configuration.capabilitiesURL)
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        configuration.decorate(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded: VoiceTrainingCapabilitiesResponse
        do {
            decoded = try decoder.decode(VoiceTrainingCapabilitiesResponse.self, from: data)
        } catch is DecodingError {
            throw VoiceTrainingServiceError.backend(message: backendMessage(from: data))
        }
        return VoiceTrainingCapabilities(
            trainingCommandConfigured: decoded.trainingCommandConfigured,
            trainingMode: decoded.trainingMode,
            supportsPersonalizedVoice: decoded.supportsPersonalizedVoice,
            message: decoded.message
        )
    }

    func submit(sample: VoiceTrainingSample) async throws -> String {
        let audioChunks = try AudioChunker.chunkedUploads(for: sample.fileURL, duration: sample.duration)
        let shouldChunk = !audioChunks.isEmpty
        let audioBase64 = shouldChunk ? nil : try Data(contentsOf: sample.fileURL).base64EncodedString()
        let body = VoiceTrainingSubmitRequest(
            transcript: sample.transcript,
            durationSeconds: sample.duration,
            fileName: sample.fileURL.lastPathComponent,
            mimeType: sample.mimeType,
            audioBase64: audioBase64,
            audioChunks: shouldChunk ? audioChunks : nil,
            baseProfileID: sample.baseProfileID?.nilIfBlank
        )

        var request = URLRequest(url: configuration.submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        configuration.decorate(&request)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded: VoiceTrainingSubmitResponse
        do {
            decoded = try decoder.decode(VoiceTrainingSubmitResponse.self, from: data)
        } catch is DecodingError {
            throw VoiceTrainingServiceError.backend(message: backendMessage(from: data))
        }
        guard !decoded.jobID.isEmpty else {
            throw VoiceTrainingServiceError.invalidResponse
        }

        return decoded.jobID
    }

    func status(for jobID: String) async throws -> VoiceTrainingJobStatus {
        var request = URLRequest(url: configuration.statusURL(for: jobID))
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        configuration.decorate(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded: VoiceTrainingStatusResponse
        do {
            decoded = try decoder.decode(VoiceTrainingStatusResponse.self, from: data)
        } catch is DecodingError {
            throw VoiceTrainingServiceError.backend(message: backendMessage(from: data))
        }
        switch decoded.status.lowercased() {
        case "queued":
            return .queued
        case "processing", "running", "training":
            return .processing(progress: decoded.progress)
        case "ready", "completed", "succeeded":
            guard let profileID = decoded.profileID, !profileID.isEmpty else {
                throw VoiceTrainingServiceError.invalidResponse
            }
            return .ready(profileID: profileID)
        case "failed", "error":
            return .failed(message: decoded.message ?? String(localized: AppStrings.voiceTrainingFailedBody))
        default:
            throw VoiceTrainingServiceError.invalidResponse
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceTrainingServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw VoiceTrainingServiceError.backend(
                message: backendMessage(from: data)
            )
        }
    }

    private func backendMessage(from data: Data) -> String {
        if let decoded = try? decoder.decode(VoiceTrainingBackendErrorResponse.self, from: data) {
            let message = decoded.message?.nilIfBlank ?? decoded.error?.nilIfBlank ?? decoded.detail?.nilIfBlank
            if let message {
                return userFacingBackendMessage(message)
            }
        }

        if
            let rawMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawMessage.isEmpty
        {
            return userFacingBackendMessage(rawMessage)
        }

        return String(localized: AppStrings.voiceTrainingFailedBody)
    }

    private func userFacingBackendMessage(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("Invalid IAP credentials") {
            return String(localized: AppStrings.voiceTrainingBackendConfigurationBody)
        }
        return message
    }
}

/// Selects the production or mock training service for the current environment.
enum VoiceTrainingServiceFactory {
    @MainActor
    static func makeDefault(
        appSessionStore: PrototypeAppSessionStore? = nil
    ) -> VoiceProfileTraining {
        let sessionToken = (appSessionStore ?? .shared).state.session?.sessionToken
        if let configuration = VoiceTrainingAPIConfiguration.load() {
            return HTTPVoiceProfileTrainingService(
                configuration: configuration,
                sessionToken: sessionToken
            )
        }

        return MockVoiceProfileTrainingService()
    }
}

/// Local fallback used when a backend training service is unavailable.
actor MockVoiceProfileTrainingService: VoiceProfileTraining {
    private var jobs: [String: Date] = [:]

    func capabilities() async throws -> VoiceTrainingCapabilities {
        VoiceTrainingCapabilities(
            trainingCommandConfigured: true,
            trainingMode: "mock",
            supportsPersonalizedVoice: true,
            message: nil
        )
    }

    func submit(sample: VoiceTrainingSample) async throws -> String {
        try await Task.sleep(for: .milliseconds(350))
        let jobID = UUID().uuidString
        jobs[jobID] = Date()
        return jobID
    }

    func status(for jobID: String) async throws -> VoiceTrainingJobStatus {
        guard let start = jobs[jobID] else {
            return .failed(message: String(localized: AppStrings.voiceTrainingFailedBody))
        }

        let elapsed = Date().timeIntervalSince(start)
        switch elapsed {
        case ..<0.9:
            return .queued
        case ..<1.8:
            return .processing(progress: 0.45)
        case ..<2.8:
            return .processing(progress: 0.8)
        default:
            return .ready(profileID: "voice-profile-\(jobID.prefix(8))")
        }
    }
}

/// `AVAudioRecorder` backed implementation for the onboarding voice sample.
final class AVAudioVoiceSampleRecorder: NSObject, VoiceSampleRecording, @unchecked Sendable {
    private var recorder: AVAudioRecorder?

    var currentTime: TimeInterval {
        recorder?.currentTime ?? 0
    }

    func start() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .denied:
            throw VoiceRecordingError.permissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                throw VoiceRecordingError.permissionDenied
            }
        @unknown default:
            throw VoiceRecordingError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-voice-\(UUID().uuidString)")
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
            throw VoiceRecordingError.failedToStart
        }

        self.recorder = recorder
    }

    func stop() async throws -> VoiceRecordedSample {
        guard let recorder else {
            throw VoiceRecordingError.missingRecording
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard duration > 0 else {
            throw VoiceRecordingError.failedToFinish
        }

        return VoiceRecordedSample(fileURL: recorder.url, duration: duration)
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

@MainActor
/// View model for recording, uploading, and tracking voice-training progress.
final class PrototypeVoiceViewModel: ObservableObject {
    @Published var stage: PrototypeVoiceStage = .prompt
    @Published private(set) var avatarImage: UIImage?
    @Published var alert: PrototypeCameraAlert?
    @Published private(set) var statusMessage: String?
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var isTraining = false
    @Published private(set) var trainedVoiceProfileID: String?

    var onBackRequested: (() -> Void)?
    var onStartRecordingRequested: (() -> Void)?
    var onStopRecordingRequested: (() -> Void)?
    var onRestartRequested: (() -> Void)?
    var onConfirmRequested: (() -> Void)?

    let title = AppStrings.voiceTitle
    let subtitle = AppStrings.voiceSubtitle
    let quote = AppStrings.voiceQuote

    private let recorder: VoiceSampleRecording
    private let trainer: VoiceProfileTraining
    private let featureFlags: FeatureFlagManaging
    private var recordedSample: VoiceRecordedSample?
    private var recordingTask: Task<Void, Never>?

    init(
        recorder: VoiceSampleRecording = AVAudioVoiceSampleRecorder(),
        trainer: VoiceProfileTraining? = nil,
        featureFlags: FeatureFlagManaging = FeatureFlagManager.shared
    ) {
        self.recorder = recorder
        self.trainer = trainer ?? VoiceTrainingServiceFactory.makeDefault()
        self.featureFlags = featureFlags
    }

    func backTapped() {
        Task {
            await recorder.cancel()
        }
        stopRecordingProgress()
        onBackRequested?()
    }

    func primaryVoiceActionTapped() {
        switch stage {
        case .prompt:
            Task {
                await startRecording()
            }
        case .recording:
            Task {
                await finishRecording()
            }
        case .complete:
            break
        }
    }

    func restartTapped() {
        recordedSample = nil
        trainedVoiceProfileID = nil
        statusMessage = nil
        alert = nil
        onRestartRequested?()
    }

    func confirmTapped() {
        Task {
            await submitVoiceProfile()
        }
    }

    func reset() {
        stage = .prompt
        avatarImage = nil
        alert = nil
        statusMessage = nil
        recordingDuration = 0
        isTraining = false
        trainedVoiceProfileID = nil
        recordedSample = nil
        stopRecordingProgress()
    }

    func prepareForRetraining(baseProfileID: String?, avatarImage: UIImage?) {
        stage = .prompt
        if let avatarImage {
            self.avatarImage = avatarImage
        }
        alert = nil
        statusMessage = nil
        recordingDuration = 0
        isTraining = false
        trainedVoiceProfileID = baseProfileID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        recordedSample = nil
        stopRecordingProgress()
        Task {
            await recorder.cancel()
        }
    }

    func setAvatarImage(_ image: UIImage?) {
        avatarImage = image
    }

    var recordingStatusText: String {
        if stage == .recording {
            return "\(String(localized: AppStrings.voiceListening)) \(formattedTime(recordingDuration))"
        }

        return String(localized: AppStrings.voiceListening)
    }

    private func startRecording() async {
        guard !isTraining else { return }

        alert = nil
        statusMessage = nil
        recordingDuration = 0

        do {
            try await recorder.start()
            beginRecordingProgress()
            onStartRecordingRequested?()
        } catch let error as VoiceRecordingError {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.voicePermissionTitle),
                message: error.errorDescription ?? String(localized: AppStrings.voiceRecordingFailedBody)
            )
        } catch {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.voiceRecordingFailedTitle),
                message: String(localized: AppStrings.voiceRecordingFailedBody)
            )
        }
    }

    private func finishRecording() async {
        do {
            let sample = try await recorder.stop()
            recordedSample = sample
            stopRecordingProgress()
            recordingDuration = sample.duration
            onStopRecordingRequested?()
        } catch {
            stopRecordingProgress()
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.voiceRecordingFailedTitle),
                message: String(localized: AppStrings.voiceRecordingFailedBody)
            )
        }
    }

    private func submitVoiceProfile() async {
        guard !isTraining else { return }
        guard let recordedSample else {
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.voiceMissingSampleTitle),
                message: String(localized: AppStrings.voiceMissingSampleBody)
            )
            return
        }

        guard featureFlags.isEnabled(.enableVoiceTraining) else {
            trainedVoiceProfileID = nil
            statusMessage = nil
            onConfirmRequested?()
            return
        }

        isTraining = true
        alert = nil
        statusMessage = String(localized: AppStrings.voiceUploading)

        do {
            let capabilities = try await trainer.capabilities()
            guard capabilities.supportsPersonalizedVoice else {
                throw VoiceTrainingServiceError.backend(
                    message: capabilities.message ?? String(localized: AppStrings.voiceTrainingFailedBody)
                )
            }

            let jobID = try await trainer.submit(
                sample: VoiceTrainingSample(
                    fileURL: recordedSample.fileURL,
                    transcript: String(localized: quote),
                    duration: recordedSample.duration,
                    baseProfileID: trainedVoiceProfileID
                )
            )

            // Cap the polling window to avoid spinning forever if the trainer
            // never reaches a terminal state. The backend's own trainer timeout
            // is 15m by default, so 20m here gives a bit of slack before we give
            // up and surface a friendly error.
            let pollStart = Date()
            let maxPollDuration: TimeInterval = 20 * 60
            while true {
                if Date().timeIntervalSince(pollStart) > maxPollDuration {
                    throw NSError(
                        domain: "VoiceTraining",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Voice training is taking longer than expected. Please try again."]
                    )
                }

                let status = try await trainer.status(for: jobID)
                switch status {
                case .queued:
                    statusMessage = String(localized: AppStrings.voiceQueued)
                case let .processing(progress):
                    if let progress {
                        statusMessage = "\(String(localized: AppStrings.voiceTraining)) \(Int(progress * 100))%"
                    } else {
                        statusMessage = String(localized: AppStrings.voiceTraining)
                    }
                case let .ready(profileID):
                    isTraining = false
                    statusMessage = nil
                    trainedVoiceProfileID = profileID
                    onConfirmRequested?()
                    return
                case let .failed(message):
                    throw NSError(domain: "VoiceTraining", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
                }

                try await Task.sleep(for: .milliseconds(450))
            }
        } catch {
            isTraining = false
            statusMessage = nil
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.voiceTrainingFailedTitle),
                message: error.localizedDescription.isEmpty
                    ? String(localized: AppStrings.voiceTrainingFailedBody)
                    : error.localizedDescription
            )
        }
    }

    private func beginRecordingProgress() {
        stopRecordingProgress()
        recordingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.recordingDuration = await recorder.currentTime
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopRecordingProgress() {
        recordingTask?.cancel()
        recordingTask = nil
    }

    private func formattedTime(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
