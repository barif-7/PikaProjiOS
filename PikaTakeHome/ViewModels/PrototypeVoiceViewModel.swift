import SwiftUI

@MainActor
final class PrototypeVoiceViewModel: ObservableObject {
    @Published var stage: PrototypeVoiceStage = .prompt

    var onBackRequested: (() -> Void)?
    var onStartRecordingRequested: (() -> Void)?
    var onStopRecordingRequested: (() -> Void)?
    var onRestartRequested: (() -> Void)?
    var onConfirmRequested: (() -> Void)?

    let title = AppStrings.voiceTitle
    let subtitle = AppStrings.voiceSubtitle
    let quote = AppStrings.voiceQuote

    func backTapped() {
        onBackRequested?()
    }

    func primaryVoiceActionTapped() {
        switch stage {
        case .prompt:
            onStartRecordingRequested?()
        case .recording:
            onStopRecordingRequested?()
        case .complete:
            break
        }
    }

    func restartTapped() {
        onRestartRequested?()
    }

    func confirmTapped() {
        onConfirmRequested?()
    }

    func reset() {
        stage = .prompt
    }
}
