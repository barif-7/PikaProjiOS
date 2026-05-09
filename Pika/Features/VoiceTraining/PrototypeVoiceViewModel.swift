//
//  PrototypeVoiceViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation
import SwiftUI
import UIKit

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
        recorder: VoiceSampleRecording? = nil,
        trainer: VoiceProfileTraining? = nil,
        featureFlags: FeatureFlagManaging = FeatureFlagManager.shared
    ) {
        let isVoiceTrainingEnabled = featureFlags.isEnabled(.enableVoiceTraining)
        self.recorder = recorder ?? (isVoiceTrainingEnabled ? AVAudioVoiceSampleRecorder() : LocalDemoVoiceSampleRecorder())
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
