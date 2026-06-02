//
//  PrototypeMessagesVoiceChatService.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation

private struct MessagesBackendHistoryMessage: Encodable {
    let role: String
    let content: String
}

private struct MessagesBackendTurnRequest: Encodable {
    let audioBase64: String?
    let audioChunks: [AudioUploadChunk]?
    let mimeType: String
    let fileName: String
    let durationSeconds: TimeInterval
    let voiceProfileID: String?
    let conversationSummary: String?
    let history: [MessagesBackendHistoryMessage]
}

private struct MessagesBackendTurnResponse: Decodable {
    let transcript: String
    let responseText: String
    let responseAudioBase64: String?
    let responseAudioMimeType: String?
    let error: String?
}

private struct MessagesBackendVoiceJobSubmitResponse: Decodable {
    let jobID: String
    let stage: String

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case stage
    }
}

private struct MessagesBackendVoiceJobStatusResponse: Decodable {
    let jobID: String
    let stage: String
    let transcript: String?
    let responseText: String?
    let responseAudioBase64: String?
    let responseAudioMimeType: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case stage
        case transcript
        case responseText
        case responseAudioBase64
        case responseAudioMimeType
        case error
    }
}

private struct MessagesBackendErrorResponse: Decodable {
    let message: String
}

/// One decoded Server-Sent Event frame from `POST /voice-chat/stream`.
private struct MessagesBackendStreamEvent: Decodable {
    let type: String
    let transcript: String?
    let delta: String?
    let audioBase64: String?
    let mimeType: String?
    let text: String?
    let responseText: String?
    let error: String?
}

/// HTTP client that sends recorded turns to the voice-chat backend.
actor HTTPMessagesVoiceChatService: MessagesVoiceChatResponding {
    private static let maxHistoryMessages = 8
    private static let requestTimeout: TimeInterval = 180

    // Exponential backoff parameters for job-status polling.
    private static let pollInitialInterval: TimeInterval = 0.5
    private static let pollMaxInterval: TimeInterval = 8.0
    private static let pollBackoffFactor: Double = 2.0
    private static let pollJitterFraction: Double = 0.1

    private let configuration: VoiceChatBackendConfiguration
    private let sessionToken: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: VoiceChatBackendConfiguration,
        sessionToken: String? = nil,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionToken = sessionToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        self.session = session
    }

    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        let requestBody = try makeRequestBody(
            recordedTurn: recordedTurn,
            history: history,
            conversationSummary: conversationSummary,
            voiceProfileID: voiceProfileID
        )
        let request = try makeRequest(url: configuration.voiceJobsURL, body: requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw MessagesVoiceChatError.backendNetworkFailed(
                message: Self.networkFailureMessage(for: error, baseURL: configuration.baseURL)
            )
        }
        try validate(response: response, data: data)

        let accepted = try decoder.decode(MessagesBackendVoiceJobSubmitResponse.self, from: data)
        return try await pollForCompletedJob(jobID: accepted.jobID)
    }

    // MARK: - Shared request building

    private func makeRequestBody(
        recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) throws -> MessagesBackendTurnRequest {
        let audioChunks = try AudioChunker.chunkedUploads(for: recordedTurn.fileURL, duration: recordedTurn.duration)
        let shouldChunk = !audioChunks.isEmpty
        let audioBase64 = shouldChunk ? nil : try Data(contentsOf: recordedTurn.fileURL).base64EncodedString()
        let trimmedHistory = history.suffix(Self.maxHistoryMessages)
        return MessagesBackendTurnRequest(
            audioBase64: audioBase64,
            audioChunks: shouldChunk ? audioChunks : nil,
            mimeType: recordedTurn.mimeType,
            fileName: recordedTurn.fileURL.lastPathComponent,
            durationSeconds: recordedTurn.duration,
            voiceProfileID: voiceProfileID,
            conversationSummary: conversationSummary?.nilIfBlank,
            history: trimmedHistory.map {
                MessagesBackendHistoryMessage(
                    role: $0.speaker == .user ? "user" : "assistant",
                    content: $0.text
                )
            }
        )
    }

    private func makeRequest(url: URL, body: MessagesBackendTurnRequest) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        configuration.decorate(&request)
        request.httpBody = try encoder.encode(body)
        return request
    }

    private static func networkFailureMessage(for error: URLError, baseURL: URL) -> String {
        switch error.code {
        case .timedOut:
            return "The voice backend took longer than \(Int(requestTimeout)) seconds to answer at \(baseURL.absoluteString). Try a shorter recording, or wait for the local models to warm up and try again."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet, .networkConnectionLost:
            return "The app could not reach the voice backend at \(baseURL.absoluteString). Make sure the phone is on the same Wi-Fi and the backend is still running."
        default:
            return "The app could not complete the voice request at \(baseURL.absoluteString): \(error.localizedDescription)"
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendError = (try? decoder.decode(MessagesBackendErrorResponse.self, from: data))?.message
                ?? (try? decoder.decode(MessagesBackendTurnResponse.self, from: data))?.error
            throw MessagesVoiceChatError.backendFailed(
                message: backendError ?? String(localized: AppStrings.messagesBackendFailedBody)
            )
        }
    }

    private func pollForCompletedJob(jobID: String) async throws -> MessagesTurnResult {
        let deadline = Date().addingTimeInterval(Self.requestTimeout)
        var pollInterval = Self.pollInitialInterval

        while Date() < deadline {
            var request = URLRequest(url: configuration.voiceJobStatusURL(jobID: jobID))
            request.httpMethod = "GET"
            request.timeoutInterval = min(30, Self.requestTimeout)
            if let sessionToken {
                request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            }
            configuration.decorate(&request)

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError {
                throw MessagesVoiceChatError.backendNetworkFailed(
                    message: Self.networkFailureMessage(for: error, baseURL: configuration.baseURL)
                )
            }
            try validate(response: response, data: data)

            let decoded = try decoder.decode(MessagesBackendVoiceJobStatusResponse.self, from: data)
            switch decoded.stage {
            case "queued", "transcribing", "generating", "synthesizing":
                // Exponential backoff with ±10 % jitter to spread polling load.
                let jitter = pollInterval * Self.pollJitterFraction * Double.random(in: -1 ... 1)
                let sleepSeconds = max(Self.pollInitialInterval, min(Self.pollMaxInterval, pollInterval + jitter))
                try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                pollInterval = min(Self.pollMaxInterval, pollInterval * Self.pollBackoffFactor)
            case "failed":
                throw MessagesVoiceChatError.backendFailed(
                    message: decoded.error ?? String(localized: AppStrings.messagesBackendFailedBody)
                )
            case "ready":
                let transcript = decoded.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let responseText = decoded.responseText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !transcript.isEmpty, !responseText.isEmpty else {
                    throw MessagesVoiceChatError.invalidResponse
                }
                let responseAudioData = decoded.responseAudioBase64.flatMap { Data(base64Encoded: $0) }
                return MessagesTurnResult(
                    transcript: transcript,
                    responseText: responseText,
                    responseAudioData: responseAudioData
                )
            default:
                throw MessagesVoiceChatError.invalidResponse
            }
        }

        throw MessagesVoiceChatError.backendFailed(
            message: "The voice backend did not finish the queued job within \(Int(Self.requestTimeout)) seconds."
        )
    }

    /// Open the SSE stream and forward each decoded event to ``continuation``.
    fileprivate func streamTurn(
        recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?,
        continuation: AsyncThrowingStream<MessagesTurnStreamEvent, Error>.Continuation
    ) async throws {
        let body = try makeRequestBody(
            recordedTurn: recordedTurn,
            history: history,
            conversationSummary: conversationSummary,
            voiceProfileID: voiceProfileID
        )
        var request = try makeRequest(url: configuration.streamURL, body: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw MessagesVoiceChatError.backendNetworkFailed(
                message: Self.networkFailureMessage(for: error, baseURL: configuration.baseURL)
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw MessagesVoiceChatError.backendFailed(
                message: String(localized: AppStrings.messagesBackendFailedBody)
            )
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, let data = payload.data(using: .utf8) else { continue }
            guard let event = try? decoder.decode(MessagesBackendStreamEvent.self, from: data) else { continue }

            switch event.type {
            case "transcript":
                let transcript = event.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !transcript.isEmpty {
                    continuation.yield(.transcript(transcript))
                }
            case "text":
                if let delta = event.delta, !delta.isEmpty {
                    continuation.yield(.textDelta(delta))
                }
            case "audio":
                if let base64 = event.audioBase64, let audio = Data(base64Encoded: base64) {
                    continuation.yield(.audio(audio))
                }
            case "done":
                let responseText = event.responseText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.yield(.done(responseText: responseText))
                return
            case "error":
                throw MessagesVoiceChatError.backendFailed(
                    message: event.error ?? String(localized: AppStrings.messagesBackendFailedBody)
                )
            default:
                break
            }
        }
    }
}

extension HTTPMessagesVoiceChatService: MessagesVoiceChatStreaming {
    nonisolated func respondStreaming(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) -> AsyncThrowingStream<MessagesTurnStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.streamTurn(
                        recordedTurn: recordedTurn,
                        history: history,
                        conversationSummary: conversationSummary,
                        voiceProfileID: voiceProfileID,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Failing chat service used when no backend URL is configured.
actor UnconfiguredMessagesVoiceChatService: MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        throw MessagesVoiceChatError.backendNotConfigured
    }
}

/// Builds the chat service from the configured backend URL and active session.
enum MessagesVoiceChatServiceFactory {
    @MainActor
    static func makeDefault(
        appSessionStore: PrototypeAppSessionStore? = nil
    ) -> MessagesVoiceChatResponding {
        let sessionToken = (appSessionStore ?? .shared).state.session?.sessionToken
        if let configuration = VoiceChatBackendConfiguration.load() {
            return HTTPMessagesVoiceChatService(
                configuration: configuration,
                sessionToken: sessionToken
            )
        }

        return UnconfiguredMessagesVoiceChatService()
    }
}
