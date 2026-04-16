import SwiftUI

@MainActor
final class PrototypeCoordinator: ObservableObject {
    @Published private(set) var route: PrototypeRoute = .welcome
    @Published private(set) var isProcessing = false

    let welcomeViewModel = PrototypeWelcomeViewModel()
    let cameraViewModel = PrototypeCameraViewModel()
    let voiceViewModel = PrototypeVoiceViewModel()
    let successViewModel = PrototypeSuccessViewModel()

    private var pendingTransitionTask: Task<Void, Never>?

    init() {
        bindViewModels()
    }

    deinit {
        pendingTransitionTask?.cancel()
    }

    var animationValue: String {
        switch route {
        case .welcome:
            return "welcome"
        case .camera:
            return "camera"
        case let .voice(stage):
            return "voice-\(String(describing: stage))"
        case .success:
            return "success"
        }
    }

    private func bindViewModels() {
        welcomeViewModel.onContinueRequested = { [weak self] in
            self?.showCamera()
        }

        cameraViewModel.onBackRequested = { [weak self] in
            self?.showWelcome()
        }
        cameraViewModel.onCaptureRequested = { [weak self] in
            self?.showVoicePrompt()
        }

        voiceViewModel.onBackRequested = { [weak self] in
            self?.showCamera()
        }
        voiceViewModel.onStartRecordingRequested = { [weak self] in
            self?.showVoiceRecording()
        }
        voiceViewModel.onStopRecordingRequested = { [weak self] in
            self?.showVoiceComplete()
        }
        voiceViewModel.onRestartRequested = { [weak self] in
            self?.showVoicePrompt()
        }
        voiceViewModel.onConfirmRequested = { [weak self] in
            self?.completeVoiceStep()
        }

        successViewModel.onCloseRequested = { [weak self] in
            self?.resetFlow()
        }
    }

    private func showWelcome() {
        route = .welcome
    }

    private func showCamera() {
        guard welcomeViewModel.canContinue else { return }
        route = .camera
    }

    private func showVoicePrompt() {
        voiceViewModel.stage = .prompt
        route = .voice(.prompt)
    }

    private func showVoiceRecording() {
        voiceViewModel.stage = .recording
        route = .voice(.recording)
    }

    private func showVoiceComplete() {
        voiceViewModel.stage = .complete
        route = .voice(.complete)
    }

    private func completeVoiceStep() {
        guard !isProcessing else { return }

        isProcessing = true
        pendingTransitionTask?.cancel()
        pendingTransitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            self.isProcessing = false
            self.route = .success
        }
    }

    private func resetFlow() {
        pendingTransitionTask?.cancel()
        isProcessing = false
        route = .welcome
        welcomeViewModel.reset()
        voiceViewModel.reset()
    }
}
