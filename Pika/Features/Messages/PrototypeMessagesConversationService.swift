//
//  PrototypeMessagesConversationService.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation
import UIKit

private struct MessagesConversationBackendMessage: Codable {
    let role: String
    let content: String
}

private struct MessagesConversationResponse: Decodable {
    let conversationID: String
    let summary: String
    let voiceProfileID: String?
    let avatarBase64: String?
    let messages: [MessagesConversationBackendMessage]

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversationId"
        case summary
        case voiceProfileID = "voiceProfileID"
        case avatarBase64 = "avatarBase64"
        case messages
    }
}

private struct MessagesConversationRequest: Encodable {
    let summary: String
    let voiceProfileID: String?
    let avatarBase64: String?
    let messages: [MessagesConversationBackendMessage]
}

private struct MessagesBackendErrorResponse: Decodable {
    let message: String
}

/// Persists conversation summaries and history through the backend.
actor HTTPMessagesConversationService: MessagesConversationPersisting {
    private let url: URL
    private let sessionToken: String
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL, sessionToken: String, session: URLSession = .shared) {
        self.url = url
        self.sessionToken = sessionToken
        self.session = session
    }

    func loadConversation() async throws -> MessagesConversationSnapshot {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoded = try decoder.decode(MessagesConversationResponse.self, from: data)
        return MessagesConversationSnapshot(
            summary: decoded.summary,
            voiceProfileID: decoded.voiceProfileID,
            avatarImage: Self.decodeAvatarImage(from: decoded.avatarBase64),
            messages: decoded.messages.compactMap(Self.mapMessage)
        )
    }

    func saveConversation(
        summary: String,
        voiceProfileID: String?,
        avatarImage: UIImage?,
        messages: [PrototypeVoiceChatMessage]
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            MessagesConversationRequest(
                summary: summary,
                voiceProfileID: voiceProfileID,
                avatarBase64: Self.encodeAvatarImage(avatarImage),
                messages: messages.map {
                    MessagesConversationBackendMessage(
                        role: $0.speaker == .user ? "user" : "assistant",
                        content: $0.text
                    )
                }
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesVoiceChatError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let backendMessage = (try? decoder.decode(MessagesBackendErrorResponse.self, from: data))?.message
            throw MessagesVoiceChatError.backendFailed(
                message: backendMessage ?? String(localized: AppStrings.messagesBackendFailedBody)
            )
        }
    }

    private static func mapMessage(_ message: MessagesConversationBackendMessage) -> PrototypeVoiceChatMessage? {
        let normalizedRole = message.role.lowercased()
        let speaker: PrototypeVoiceChatMessage.Speaker
        switch normalizedRole {
        case "user":
            speaker = .user
        case "assistant":
            speaker = .semi
        default:
            return nil
        }

        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }
        return PrototypeVoiceChatMessage(speaker: speaker, text: trimmedContent)
    }

    private static func decodeAvatarImage(from base64: String?) -> UIImage? {
        guard let base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private static func encodeAvatarImage(_ image: UIImage?) -> String? {
        guard let image else { return nil }
        return image
            .resizedForConversationAvatar(maxDimension: 512)?
            .jpegData(compressionQuality: 0.82)?
            .base64EncodedString()
    }
}

/// Builds the conversation persistence service from auth configuration.
enum MessagesConversationServiceFactory {
    @MainActor
    static func makeDefault(
        authConfiguration: AuthBackendConfiguration? = AuthBackendConfiguration.load(),
        appSessionStore: PrototypeAppSessionStore? = nil
    ) -> MessagesConversationPersisting? {
        let appSessionStore = appSessionStore ?? .shared
        guard
            let authConfiguration,
            let sessionToken = appSessionStore.state.session?.sessionToken,
            !sessionToken.isEmpty
        else {
            return nil
        }

        return HTTPMessagesConversationService(
            url: authConfiguration.baseURL.appendingPathComponent("conversations").appendingPathComponent("default"),
            sessionToken: sessionToken
        )
    }
}
