//
//  PrototypeMessagesViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
/// View model for the voice-chat conversation experience.
final class PrototypeMessagesViewModel: ObservableObject {
    private static let recentContextMessages = 8
    private static let summaryMaxCharacters = 1_200
    private static let summaryEntryMaxCharacters = 140
    private static let initialMessages = [
        PrototypeVoiceChatMessage(
            speaker: .semi,
            text: "I am here. Talk to me like you would talk to your future self."
        )
    ]

    @Published private(set) var avatarImage: UIImage?
    @Published private(set) var callState: PrototypeMessagesCallState = .idle
    @Published private(set) var statusText = String(localized: AppStrings.messagesStatusReady)
    @Published private(set) var messages: [PrototypeVoiceChatMessage] = PrototypeMessagesViewModel.initialMessages
    @Published var alert: PrototypeCameraAlert?

    var onBackRequested: (() -> Void)?
    var onOpenProviderSettingsRequested: (() -> Void)?
    var onRetrainVoiceRequested: (() -> Void)?
    var onUpdateAvatarRequested: (() -> Void)?

    private let recorder: MessagesVoiceRecorder
    private let chatService: MessagesVoiceChatResponding
    private let conversationStore: MessagesConversationPersisting?
    private let audioPlayer: MessagesAudioPlaying
    private let featureFlags: FeatureFlagManaging
    private let isBackendConfigured: Bool
    private var voiceProfileID: String?
    private var conversationSummary = ""
    private var hasLoadedPersistedConversation = false

    let title = AppStrings.messagesTitle
    let subtitle = AppStrings.messagesSubtitle
    let hint = AppStrings.messagesHint

    init(
        recorder: MessagesVoiceRecorder? = nil,
        chatService: MessagesVoiceChatResponding? = nil,
        conversationStore: MessagesConversationPersisting? = nil,
        audioPlayer: MessagesAudioPlaying? = nil,
        featureFlags: FeatureFlagManaging = FeatureFlagManager.shared
    ) {
        let isVoiceChatEnabled = featureFlags.isEnabled(.enableVoiceChat)
        let resolvedChatService = chatService ?? MessagesVoiceChatServiceFactory.makeDefault()
        self.recorder = recorder ?? MessagesAudioRecorder()
        self.chatService = resolvedChatService
        self.conversationStore = isVoiceChatEnabled
            ? (conversationStore ?? MessagesConversationServiceFactory.makeDefault())
            : nil
        self.audioPlayer = audioPlayer ?? MessagesAudioPlayer()
        self.featureFlags = featureFlags
        self.isBackendConfigured = !(resolvedChatService is UnconfiguredMessagesVoiceChatService)
    }

    func setAvatarImage(_ image: UIImage?) {
        avatarImage = image
    }

    func setVoiceProfileID(_ profileID: String?) {
        voiceProfileID = profileID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        Task {
            await persistConversationIfPossible()
        }
    }

    func saveConversationNow() async {
        await persistConversationIfPossible()
    }

    func reset() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        avatarImage = nil
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        messages = PrototypeMessagesViewModel.initialMessages
        alert = nil
        voiceProfileID = nil
        conversationSummary = ""
        hasLoadedPersistedConversation = false
    }

    func backTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onBackRequested?()
    }

    func primaryActionTapped() {
        switch callState {
        case .idle:
            guard !featureFlags.isEnabled(.enableVoiceChat) || isBackendConfigured else {
                presentAlert(for: .backendNotConfigured)
                return
            }
            guard !featureFlags.isEnabled(.enableVoiceChat) || voiceProfileID?.nilIfBlank != nil else {
                presentAlert(for: .voiceProfileRequired)
                return
            }
            Task {
                await startListening()
            }
        case .listening:
            Task {
                await finishUserTurn()
            }
        case .responding:
            break
        }
    }

    func endCallTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
    }

    func retrainVoiceTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onRetrainVoiceRequested?()
    }

    func updateAvatarTapped() {
        Task {
            await recorder.cancel()
        }
        audioPlayer.stop()
        callState = .idle
        statusText = String(localized: AppStrings.messagesStatusReady)
        onUpdateAvatarRequested?()
    }

    func openProviderSettingsTapped() {
        onOpenProviderSettingsRequested?()
    }

    var primaryButtonTitle: LocalizedStringResource {
        switch callState {
        case .idle, .responding:
            return AppStrings.messagesStartTalking
        case .listening:
            return AppStrings.messagesFinishTurn
        }
    }

    var isPrimaryButtonEnabled: Bool {
        callState != .responding
    }

    var showsProviderSettingsButton: Bool {
        featureFlags.isEnabled(.enableVoiceChat)
    }

    var showsRetrainVoiceButton: Bool {
        featureFlags.isEnabled(.enableVoiceTraining)
    }

    func prepareConversation() async {
        guard !hasLoadedPersistedConversation else { return }
        hasLoadedPersistedConversation = true
        guard let conversationStore else { return }
        let preferredVoiceProfileID = voiceProfileID?.nilIfBlank
        let preferredAvatarImage = avatarImage

        do {
            let snapshot = try await conversationStore.loadConversation()
            let storedVoiceProfileID = snapshot.voiceProfileID?.nilIfBlank
            if snapshot.messages.isEmpty {
                messages = PrototypeMessagesViewModel.initialMessages
                conversationSummary = snapshot.summary
            } else {
                messages = snapshot.messages
                conversationSummary = snapshot.summary
            }

            let resolvedVoiceProfileID = preferredVoiceProfileID ?? storedVoiceProfileID
            voiceProfileID = resolvedVoiceProfileID
            avatarImage = preferredAvatarImage ?? snapshot.avatarImage
            if preferredVoiceProfileID != nil, preferredVoiceProfileID != storedVoiceProfileID {
                await persistConversationIfPossible()
            } else if preferredAvatarImage != nil, snapshot.avatarImage == nil {
                await persistConversationIfPossible()
            }
        } catch {
            // Keep the current in-memory conversation when sync fails.
        }
    }

    private func startListening() async {
        alert = nil

        do {
            try await recorder.start()
            callState = .listening
            statusText = String(localized: AppStrings.messagesStatusListening)
        } catch let error as MessagesVoiceChatError {
            presentAlert(for: error)
        } catch {
            presentAlert(for: .failedToStartRecording)
        }
    }

    private func finishUserTurn() async {
        do {
            let recordedTurn = try await recorder.stop()
            callState = .responding
            statusText = String(localized: AppStrings.messagesStatusResponding)

            guard featureFlags.isEnabled(.enableVoiceChat) else {
                appendLocalDemoTurn(recordedTurn)
                callState = .idle
                statusText = String(localized: AppStrings.messagesStatusReady)
                return
            }

            let result = try await chatService.respond(
                to: recordedTurn,
                history: messages,
                conversationSummary: conversationSummary,
                voiceProfileID: voiceProfileID
            )
            messages.append(PrototypeVoiceChatMessage(speaker: .user, text: result.transcript))
            messages.append(PrototypeVoiceChatMessage(speaker: .semi, text: result.responseText))
            rebuildConversationSummary()
            await persistConversationIfPossible()

            if let responseAudioData = result.responseAudioData {
                try audioPlayer.play(responseAudioData)
            } else {
                presentAlert(for: .textOnlyResponse)
            }

            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
        } catch let error as MessagesVoiceChatError {
            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
            presentAlert(for: error)
        } catch {
            callState = .idle
            statusText = String(localized: AppStrings.messagesStatusReady)
            presentAlert(for: .backendFailed(message: String(localized: AppStrings.messagesBackendFailedBody)))
        }
    }

    private func appendLocalDemoTurn(_ recordedTurn: MessagesRecordedTurn) {
        messages.append(
            PrototypeVoiceChatMessage(
                speaker: .user,
                text: "Voice note recorded locally (\(formattedDuration(recordedTurn.duration)))."
            )
        )
        messages.append(
            PrototypeVoiceChatMessage(
                speaker: .semi,
                text: "Voice Chat is disabled, so this UI-only flow is not sending audio to the service yet."
            )
        )
        rebuildConversationSummary()
    }

    private func presentAlert(for error: MessagesVoiceChatError) {
        alert = PrototypeCameraAlert(
            title: error.title,
            message: error.errorDescription ?? String(localized: AppStrings.messagesBackendFailedBody)
        )
    }

    private func rebuildConversationSummary() {
        let archivedMessages = messages.dropLast(Self.recentContextMessages)
        guard !archivedMessages.isEmpty else {
            conversationSummary = ""
            return
        }

        var selectedLines: [String] = []
        var consumedCharacters = 0

        for message in archivedMessages.reversed() {
            let normalizedText = message.text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedText.isEmpty else { continue }

            let truncatedText: String
            if normalizedText.count > Self.summaryEntryMaxCharacters {
                truncatedText = String(normalizedText.prefix(Self.summaryEntryMaxCharacters - 3)) + "..."
            } else {
                truncatedText = normalizedText
            }

            let rolePrefix = message.speaker == .user ? "User" : "SEMI"
            let line = "\(rolePrefix): \(truncatedText)"
            let lineCost = line.count + (selectedLines.isEmpty ? 0 : 1)
            if consumedCharacters + lineCost > Self.summaryMaxCharacters {
                break
            }

            selectedLines.append(line)
            consumedCharacters += lineCost
        }

        conversationSummary = selectedLines.reversed().joined(separator: "\n")
    }

    private func persistConversationIfPossible() async {
        guard let conversationStore else { return }

        do {
            try await conversationStore.saveConversation(
                summary: conversationSummary,
                voiceProfileID: voiceProfileID,
                avatarImage: avatarImage,
                messages: messages
            )
        } catch {
            // Persistence is best-effort so local chat remains usable even if sync fails.
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension UIImage {
    public func resizedForConversationAvatar(maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
