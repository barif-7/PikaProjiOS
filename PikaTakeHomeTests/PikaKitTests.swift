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
