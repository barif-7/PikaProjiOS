@preconcurrency import AVFAudio
import Foundation
import SwiftUI
import UIKit

struct VoiceRecordedSample {
    let fileURL: URL
    let duration: TimeInterval
}

struct VoiceTrainingSample {
    let fileURL: URL
    let transcript: String
    let duration: TimeInterval
}

enum VoiceTrainingJobStatus: Equatable {
    case queued
    case processing(progress: Double?)
    case ready(profileID: String)
    case failed(message: String)
}

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

protocol VoiceSampleRecording {
    func start() async throws
    func stop() async throws -> VoiceRecordedSample
    func cancel() async
    var currentTime: TimeInterval { get async }
}

protocol VoiceProfileTraining {
    func capabilities() async throws -> VoiceTrainingCapabilities
    func submit(sample: VoiceTrainingSample) async throws -> String
    func status(for jobID: String) async throws -> VoiceTrainingJobStatus
}

struct VoiceTrainingCapabilities: Equatable {
    let trainingCommandConfigured: Bool
    let trainingMode: String
    let supportsPersonalizedVoice: Bool
    let message: String?
}

struct VoiceTrainingAPIConfiguration {
    let baseURL: URL
    private static let simulatorDefaultBaseURL = URL(string: "http://127.0.0.1:8080")!

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> VoiceTrainingAPIConfiguration? {
        let environmentValue = processInfo.environment["VOICE_TRAINING_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue, !environmentValue.isEmpty, let url = URL(string: environmentValue) {
            return VoiceTrainingAPIConfiguration(baseURL: url)
        }

        #if targetEnvironment(simulator)
        return VoiceTrainingAPIConfiguration(baseURL: simulatorDefaultBaseURL)
        #else
        let plistValue = (bundle.object(forInfoDictionaryKey: "VoiceTrainingBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistValue, !plistValue.isEmpty, let url = URL(string: plistValue) {
            return VoiceTrainingAPIConfiguration(baseURL: url)
        }
        #endif

        return nil
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

private struct VoiceTrainingSubmitRequest: Encodable {
    let transcript: String
    let durationSeconds: TimeInterval
    let fileName: String
    let mimeType: String
    let audioBase64: String
}

private struct VoiceTrainingSubmitResponse: Decodable {
    let jobID: String

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
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

actor HTTPVoiceProfileTrainingService: VoiceProfileTraining {
    private let configuration: VoiceTrainingAPIConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: VoiceTrainingAPIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func capabilities() async throws -> VoiceTrainingCapabilities {
        let (data, response) = try await session.data(from: configuration.capabilitiesURL)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(VoiceTrainingCapabilitiesResponse.self, from: data)
        return VoiceTrainingCapabilities(
            trainingCommandConfigured: decoded.trainingCommandConfigured,
            trainingMode: decoded.trainingMode,
            supportsPersonalizedVoice: decoded.supportsPersonalizedVoice,
            message: decoded.message
        )
    }

    func submit(sample: VoiceTrainingSample) async throws -> String {
        let audioData = try Data(contentsOf: sample.fileURL)
        let body = VoiceTrainingSubmitRequest(
            transcript: sample.transcript,
            durationSeconds: sample.duration,
            fileName: sample.fileURL.lastPathComponent,
            mimeType: "audio/m4a",
            audioBase64: audioData.base64EncodedString()
        )

        var request = URLRequest(url: configuration.submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(VoiceTrainingSubmitResponse.self, from: data)
        guard !decoded.jobID.isEmpty else {
            throw VoiceTrainingServiceError.invalidResponse
        }

        return decoded.jobID
    }

    func status(for jobID: String) async throws -> VoiceTrainingJobStatus {
        let (data, response) = try await session.data(from: configuration.statusURL(for: jobID))
        try validate(response: response, data: data)

        let decoded = try decoder.decode(VoiceTrainingStatusResponse.self, from: data)
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
            let backendMessage = (try? decoder.decode(VoiceTrainingStatusResponse.self, from: data))?.message
            throw VoiceTrainingServiceError.backend(
                message: backendMessage ?? String(localized: AppStrings.voiceTrainingFailedBody)
            )
        }
    }
}

enum VoiceTrainingServiceFactory {
    static func makeDefault() -> VoiceProfileTraining {
        if let configuration = VoiceTrainingAPIConfiguration.load() {
            return HTTPVoiceProfileTrainingService(configuration: configuration)
        }

        return MockVoiceProfileTrainingService()
    }
}

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
    private var recordedSample: VoiceRecordedSample?
    private var recordingTask: Task<Void, Never>?

    init(
        recorder: VoiceSampleRecording = AVAudioVoiceSampleRecorder(),
        trainer: VoiceProfileTraining = VoiceTrainingServiceFactory.makeDefault()
    ) {
        self.recorder = recorder
        self.trainer = trainer
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
                    duration: recordedSample.duration
                )
            )

            while true {
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
