//
//  PikaKitTests.swift
//  PikaTakeHomeTests
//
//  Created by Basil Arif on 4/20/26.
//

import XCTest
import Foundation
@testable import PikaTakeHome

final class PikaKitTests: XCTestCase {
    func testPikaKitExposesDefaultProviders() {
        XCTAssertTrue(PikaKit.current.fonts is PikaFontProvider)
        XCTAssertTrue(PikaKit.current.colors is PikaColorProvider)
        XCTAssertTrue(PikaKit.current.images is PikaImageProvider)
        XCTAssertEqual(PikaSystemImage.microphone.rawValue, "mic.fill")
    }

    func testPikaKitResolvesImportedAssetPaths() {
        XCTAssertNotNil(PikaKit.Images.path(for: .voiceBackground))
    }

    @MainActor
    func testPrepareConversationPersistsPreferredVoiceProfileIDWhenBackendIsEmpty() async {
        let store = MockMessagesConversationStore(
            snapshot: MessagesConversationSnapshot(summary: "", voiceProfileID: nil, messages: [])
        )
        let viewModel = PrototypeMessagesViewModel(
            recorder: MockMessagesVoiceRecorder(),
            chatService: MockMessagesVoiceChatService(),
            conversationStore: store,
            audioPlayer: MockMessagesAudioPlayer()
        )

        viewModel.setVoiceProfileID(" voice-profile-new ")
        await viewModel.prepareConversation()

        let savedProfileID = await store.lastSavedVoiceProfileID
        XCTAssertEqual(savedProfileID, "voice-profile-new")
    }

    @MainActor
    func testPrepareConversationHydratesStoredVoiceProfileIDWhenLocalIsEmpty() async {
        let store = MockMessagesConversationStore(
            snapshot: MessagesConversationSnapshot(summary: "", voiceProfileID: "voice-profile-stored", messages: [])
        )
        let viewModel = PrototypeMessagesViewModel(
            recorder: MockMessagesVoiceRecorder(),
            chatService: MockMessagesVoiceChatService(),
            conversationStore: store,
            audioPlayer: MockMessagesAudioPlayer()
        )

        await viewModel.prepareConversation()

        let savedProfileID = await store.lastSavedVoiceProfileID
        XCTAssertNil(savedProfileID)
    }

    func testVoiceChatRequestSerializesVoiceProfileIDOverride() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-test-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try Data("test-audio".utf8).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = HTTPMessagesVoiceChatService(
            configuration: VoiceChatBackendConfiguration(baseURL: URL(string: "https://example.com")!),
            sessionToken: "session-token",
            session: session
        )

        MockURLProtocol.requestHandler = { request in
            let body = try XCTUnwrap(request.httpBody)
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(jsonObject["voiceProfileID"] as? String, "voice-profile-override")

            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/voice-chat/turn")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")

            let responseBody = """
            {
              "transcript": "hello",
              "responseText": "hi",
              "responseAudioBase64": null,
              "responseAudioMimeType": null,
              "error": null
            }
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseBody.utf8))
        }
        defer { MockURLProtocol.requestHandler = nil }

        _ = try await service.respond(
            to: MessagesRecordedTurn(fileURL: audioURL, duration: 1.25),
            history: [],
            conversationSummary: "summary",
            voiceProfileID: "voice-profile-override"
        )
    }
}

private actor MockMessagesConversationStore: MessagesConversationPersisting {
    private let snapshot: MessagesConversationSnapshot
    private(set) var lastSavedVoiceProfileID: String?

    init(snapshot: MessagesConversationSnapshot) {
        self.snapshot = snapshot
    }

    func loadConversation() async throws -> MessagesConversationSnapshot {
        snapshot
    }

    func saveConversation(
        summary: String,
        voiceProfileID: String?,
        messages: [PrototypeVoiceChatMessage]
    ) async throws {
        lastSavedVoiceProfileID = voiceProfileID
    }
}

private actor MockMessagesVoiceRecorder: MessagesVoiceRecorder {
    func start() async throws {}

    func stop() async throws -> MessagesRecordedTurn {
        throw MessagesVoiceChatError.failedToStopRecording
    }

    func cancel() async {}
}

private actor MockMessagesVoiceChatService: MessagesVoiceChatResponding {
    func respond(
        to recordedTurn: MessagesRecordedTurn,
        history: [PrototypeVoiceChatMessage],
        conversationSummary: String?,
        voiceProfileID: String?
    ) async throws -> MessagesTurnResult {
        MessagesTurnResult(transcript: "hello", responseText: "hi", responseAudioData: nil)
    }
}

@MainActor
private final class MockMessagesAudioPlayer: MessagesAudioPlaying {
    func play(_ audioData: Data) throws {}

    func stop() {}
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
