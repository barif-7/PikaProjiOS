//
//  PikaKitTests.swift
//  PikaTakeHomeTests
//
//  Created by Basil Arif on 4/20/26.
//

import AVFAudio
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
            snapshot: MessagesConversationSnapshot(summary: "", voiceProfileID: nil, avatarImage: nil, messages: [])
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
            snapshot: MessagesConversationSnapshot(summary: "", voiceProfileID: "voice-profile-stored", avatarImage: nil, messages: [])
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

        var seenSubmit = false
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
            if request.httpMethod == "POST" {
                let body = try XCTUnwrap(request.httpBody)
                let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(jsonObject["voiceProfileID"] as? String, "voice-profile-override")
                XCTAssertEqual(url.path, "/voice-chat/jobs")
                seenSubmit = true

                let responseBody = """
                {
                  "jobId": "job-123",
                  "stage": "queued"
                }
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(responseBody.utf8))
            }

            XCTAssertTrue(seenSubmit)
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(url.path, "/voice-chat/jobs/job-123")

            let responseBody = """
            {
              "jobId": "job-123",
              "stage": "ready",
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

    func testAudioChunkerSplitsLongRecordingsIntoFifteenSecondSegments() throws {
        let audioURL = try makeSilentAudioFile(duration: 31)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let chunks = try AudioChunker.chunkedUploads(for: audioURL, duration: 31)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertEqual(chunks[0].totalChunks, 3)
        XCTAssertEqual(chunks[1].index, 1)
        XCTAssertEqual(chunks[2].index, 2)
        XCTAssertLessThanOrEqual(chunks[0].durationSeconds, 15.0)
        XCTAssertLessThanOrEqual(chunks[1].durationSeconds, 15.0)
        XCTAssertLessThanOrEqual(chunks[2].durationSeconds, 15.0)
        XCTAssertTrue(chunks.allSatisfy { !$0.audioBase64.isEmpty })
    }

    func testVoiceChatRequestUsesChunkedAudioForLongRecordings() async throws {
        let audioURL = try makeSilentAudioFile(duration: 31)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = HTTPMessagesVoiceChatService(
            configuration: VoiceChatBackendConfiguration(baseURL: URL(string: "https://example.com")!),
            sessionToken: "session-token",
            session: session
        )

        var inspectedRequest = false
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                let body = try XCTUnwrap(request.httpBody)
                let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertNil(jsonObject["audioBase64"])
                let chunks = try XCTUnwrap(jsonObject["audioChunks"] as? [[String: Any]])
                XCTAssertEqual(chunks.count, 3)
                XCTAssertEqual(jsonObject["durationSeconds"] as? Double, 31)
                inspectedRequest = true

                let responseBody = """
                {
                  "jobId": "job-123",
                  "stage": "queued"
                }
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(responseBody.utf8))
            }

            XCTAssertTrue(inspectedRequest)
            let responseBody = """
            {
              "jobId": "job-123",
              "stage": "ready",
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
            to: MessagesRecordedTurn(fileURL: audioURL, duration: 31),
            history: [],
            conversationSummary: "summary",
            voiceProfileID: "voice-profile-override"
        )
    }

    func testVoiceTrainingRequestUsesChunkedAudioForLongRecordings() async throws {
        let audioURL = try makeSilentAudioFile(duration: 31)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = HTTPVoiceProfileTrainingService(
            configuration: VoiceTrainingAPIConfiguration(baseURL: URL(string: "https://example.com")!),
            sessionToken: "session-token",
            session: session
        )

        var inspectedRequest = false
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                let body = try XCTUnwrap(request.httpBody)
                let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertNil(jsonObject["audioBase64"])
                let chunks = try XCTUnwrap(jsonObject["audioChunks"] as? [[String: Any]])
                XCTAssertEqual(chunks.count, 3)
                XCTAssertEqual(jsonObject["durationSeconds"] as? Double, 31)
                inspectedRequest = true

                let responseBody = """
                {
                  "jobId": "job-123",
                  "profileId": "profile-123"
                }
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(responseBody.utf8))
            }

            XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        _ = try await service.submit(
            sample: VoiceTrainingSample(
                fileURL: audioURL,
                transcript: "testing voice chunking",
                duration: 31,
                baseProfileID: nil
            )
        )

        XCTAssertTrue(inspectedRequest)
    }

    private func makeSilentAudioFile(duration: TimeInterval) throws -> URL {
        let sampleRate = 16_000.0
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-audio-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCapacity = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
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
        avatarImage: UIImage?,
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
