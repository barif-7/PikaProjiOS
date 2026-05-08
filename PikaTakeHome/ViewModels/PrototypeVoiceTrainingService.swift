//
//  PrototypeVoiceTrainingService.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation

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
