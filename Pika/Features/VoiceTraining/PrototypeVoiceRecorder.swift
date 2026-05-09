//
//  PrototypeVoiceRecorder.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

@preconcurrency import AVFAudio
import Foundation

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

/// Lightweight recorder used when voice training is disabled but the prototype UI remains visible.
final class LocalDemoVoiceSampleRecorder: VoiceSampleRecording, @unchecked Sendable {
    private var startedAt: Date?

    var currentTime: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    func start() async throws {
        startedAt = Date()
    }

    func stop() async throws -> VoiceRecordedSample {
        guard let startedAt else {
            throw VoiceRecordingError.missingRecording
        }

        self.startedAt = nil
        let duration = max(0.1, Date().timeIntervalSince(startedAt))
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-voice-demo-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        return VoiceRecordedSample(fileURL: fileURL, duration: duration)
    }

    func cancel() async {
        startedAt = nil
    }
}
