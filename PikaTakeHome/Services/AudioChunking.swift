//
//  AudioChunking.swift
//  PikaTakeHome
//
//  Created by Codex on 5/1/26.
//

@preconcurrency import AVFAudio
import Foundation

/// Encoded audio chunk metadata sent to the backend for large uploads.
struct AudioUploadChunk: Encodable, Equatable {
    let index: Int
    let totalChunks: Int
    let fileName: String
    let mimeType: String
    let durationSeconds: TimeInterval
    let audioBase64: String
}

/// Splits linear PCM audio files into backend-friendly chunks.
enum AudioChunker {
    static let chunkDurationSeconds: TimeInterval = 15

    static func chunkedUploads(
        for fileURL: URL,
        duration: TimeInterval,
        chunkDurationSeconds: TimeInterval = chunkDurationSeconds
    ) throws -> [AudioUploadChunk] {
        guard duration > chunkDurationSeconds else {
            return []
        }

        let inputFile = try AVAudioFile(forReading: fileURL)
        let sourceFormat = inputFile.processingFormat
        guard sourceFormat.sampleRate > 0 else {
            return []
        }

        let framesPerChunk = AVAudioFrameCount(sourceFormat.sampleRate * chunkDurationSeconds)
        guard framesPerChunk > 0 else {
            return []
        }

        var chunkURLs: [URL] = []
        var chunkDurations: [TimeInterval] = []
        var chunkCount = 0

        while inputFile.framePosition < inputFile.length {
            let remainingFrames = inputFile.length - inputFile.framePosition
            let chunkFrameCount = AVAudioFrameCount(min(AVAudioFramePosition(framesPerChunk), remainingFrames))
            guard chunkFrameCount > 0 else { break }

            let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkFrameCount)
            guard let buffer else {
                throw AudioChunkingError.bufferAllocationFailed
            }

            try inputFile.read(into: buffer, frameCount: chunkFrameCount)

            let chunkURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("pika-audio-chunk-\(UUID().uuidString)-\(chunkCount)")
                .appendingPathExtension(fileURL.pathExtension.nilIfBlank ?? "wav")

            let chunkFile = try AVAudioFile(
                forWriting: chunkURL,
                settings: inputFile.fileFormat.settings,
                commonFormat: sourceFormat.commonFormat,
                interleaved: sourceFormat.isInterleaved
            )
            try chunkFile.write(from: buffer)

            chunkURLs.append(chunkURL)
            chunkDurations.append(TimeInterval(buffer.frameLength) / sourceFormat.sampleRate)
            chunkCount += 1
        }

        guard !chunkURLs.isEmpty else {
            return []
        }

        let totalChunks = chunkURLs.count
        var uploads: [AudioUploadChunk] = []
        uploads.reserveCapacity(totalChunks)

        for (index, chunkURL) in chunkURLs.enumerated() {
            let data = try Data(contentsOf: chunkURL)
            uploads.append(
                AudioUploadChunk(
                    index: index,
                    totalChunks: totalChunks,
                    fileName: chunkURL.lastPathComponent,
                    mimeType: mimeType(for: chunkURL),
                    durationSeconds: chunkDurations[index],
                    audioBase64: data.base64EncodedString()
                )
            )
            try? FileManager.default.removeItem(at: chunkURL)
        }

        return uploads
    }

    static func shouldChunk(duration: TimeInterval, chunkDurationSeconds: TimeInterval = chunkDurationSeconds) -> Bool {
        duration > chunkDurationSeconds
    }

    private static func mimeType(for fileURL: URL) -> String {
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

enum AudioChunkingError: LocalizedError {
    case bufferAllocationFailed

    var errorDescription: String? {
        "Could not split the recorded audio into upload chunks."
    }
}
