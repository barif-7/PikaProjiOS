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

/// Lightweight recorder used when voice chat is disabled but the prototype UI remains visible.
final class LocalDemoMessagesVoiceRecorder: MessagesVoiceRecorder, @unchecked Sendable {
    private var startedAt: Date?

    func start() async throws {
        startedAt = Date()
    }

    func stop() async throws -> MessagesRecordedTurn {
        guard let startedAt else {
            throw MessagesVoiceChatError.failedToStopRecording
        }

        self.startedAt = nil
        let duration = max(0.1, Date().timeIntervalSince(startedAt))
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-messages-demo-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        return MessagesRecordedTurn(fileURL: fileURL, duration: duration)
    }

    func cancel() async {
        startedAt = nil
    }
}

@MainActor
/// Small `AVAudioPlayer` wrapper for backend response audio.
///
/// Supports both single-shot playback (``play(_:)``) for the non-streaming
/// path and a sequential queue (``enqueue(_:)``) for the streaming path, where
/// each sentence's audio arrives separately and must play back to back.
final class MessagesAudioPlayer: NSObject, MessagesAudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var queue: [Data] = []

    /// Replace any queued/playing audio and play this clip immediately.
    func play(_ audioData: Data) throws {
        stop()
        queue = [audioData]
        try playNextIfIdle()
    }

    /// Add audio to the end of the playback queue; starts playback if idle.
    func enqueue(_ audioData: Data) throws {
        queue.append(audioData)
        try playNextIfIdle()
    }

    func stop() {
        queue.removeAll()
        player?.stop()
        player = nil
    }

    private func playNextIfIdle() throws {
        guard player == nil, !queue.isEmpty else { return }
        let data = queue.removeFirst()
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        player.delegate = self
        guard player.play() else {
            throw MessagesVoiceChatError.invalidResponse
        }
        self.player = player
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            try? self.playNextIfIdle()
        }
    }
}
