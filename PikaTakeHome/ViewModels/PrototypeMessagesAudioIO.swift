//
//  PrototypeMessagesAudioIO.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

@preconcurrency import AVFAudio
import Foundation

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
