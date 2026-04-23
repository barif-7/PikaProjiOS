//
//  PrototypeCoordinator.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Owns app-level navigation and wires screen view models together.
@MainActor
final class PrototypeCoordinator: ObservableObject {
    // The active screen in the prototype flow.
    @Published private(set) var route: PrototypeRoute
    // Tracks whether the coordinator is currently performing a transient flow action.
    @Published private(set) var isProcessing = false

    // The welcome screen view model is created eagerly because it is needed on launch.
    let welcomeViewModel: PrototypeWelcomeViewModel

    private let sessionStore: PrototypeSessionStore
    private let appSessionStore: PrototypeAppSessionStore
    private let googleAuthService: PrototypeGoogleAuthenticating?
    private let featureFlags: FeatureFlagManaging

    // Lazily-created screen view models are cached so flow state can survive route changes.
    private var storedCameraViewModel: PrototypeCameraViewModel?
    private var storedVoiceViewModel: PrototypeVoiceViewModel?
    private var storedSuccessViewModel: PrototypeSuccessViewModel?
    private var storedMessagesViewModel: PrototypeMessagesViewModel?
    private var storedProviderSettingsViewModel: PrototypeProviderSettingsViewModel?

    // Used to cancel any in-flight transition work when the flow resets or deinitializes.
    private var pendingTransitionTask: Task<Void, Never>?
    private var isRetrainingVoiceProfile = false

    init(
        sessionStore: PrototypeSessionStore? = nil,
        appSessionStore: PrototypeAppSessionStore? = nil,
        googleAuthService: PrototypeGoogleAuthenticating? = nil,
        featureFlags: FeatureFlagManaging = FeatureFlagManager.shared
    ) {
        let sessionStore = sessionStore ?? .shared
        let appSessionStore = appSessionStore ?? .shared
        
        self.sessionStore = sessionStore
        self.appSessionStore = appSessionStore
        self.googleAuthService = googleAuthService ?? PrototypeGoogleAuthServiceFactory.makeDefault()
        self.featureFlags = featureFlags
        
        let sessionState = sessionStore.state
        self.welcomeViewModel = PrototypeWelcomeViewModel(phoneNumber: sessionState.phoneNumber)
        
        self.route = Self.defaultRoute(for: sessionState)
        bindWelcomeViewModel()
    }

    deinit {
        pendingTransitionTask?.cancel()
    }

    /// Stable value used to animate route transitions in the root coordinator view.
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
        case .messages:
            return "messages"
        case .providerSettings:
            return "provider-settings"
        }
    }

    // Lazily instantiates and memoizes the camera screen view model.
    /// Lazily-created camera view model so generated state survives route switches.
    lazy var cameraViewModel: PrototypeCameraViewModel = {
        if let storedCameraViewModel {
            return storedCameraViewModel
        }
        let viewModel = makeCameraViewModel()
        storedCameraViewModel = viewModel
        return viewModel
    }()

    // Lazily instantiates and memoizes the voice screen view model.
    /// Lazily-created voice view model so recording/training state is retained.
    lazy var voiceViewModel: PrototypeVoiceViewModel = {
        if let storedVoiceViewModel {
            return storedVoiceViewModel
        }
        let viewModel = makeVoiceViewModel()
        storedVoiceViewModel = viewModel
        return viewModel
    }()

    // Lazily instantiates and memoizes the success screen view model.
    /// Lazily-created success view model containing the generated identity card.
    lazy var successViewModel: PrototypeSuccessViewModel = {
        if let storedSuccessViewModel {
            return storedSuccessViewModel
        }
        let viewModel = makeSuccessViewModel()
        storedSuccessViewModel = viewModel
        return viewModel
    }()

    // Lazily instantiates and memoizes the messages screen view model.
    /// Lazily-created chat view model configured after voice onboarding.
    lazy var messagesViewModel: PrototypeMessagesViewModel = {
        if let storedMessagesViewModel {
            return storedMessagesViewModel
        }
        let viewModel = makeMessagesViewModel()
        storedMessagesViewModel = viewModel
        return viewModel
    }()

    // Lazily instantiates and memoizes the provider settings screen view model.
    /// Lazily-created provider settings view model for Ollama connection management.
    lazy var providerSettingsViewModel: PrototypeProviderSettingsViewModel = {
        if let storedProviderSettingsViewModel {
            return storedProviderSettingsViewModel
        }
        let viewModel = makeProviderSettingsViewModel()
        storedProviderSettingsViewModel = viewModel
        return viewModel
    }()

    // Wires the welcome screen callbacks into coordinator navigation and auth actions.
    private func bindWelcomeViewModel() {
        welcomeViewModel.onContinueRequested = { [weak self] in
            guard let self else { return }
            self.sessionStore.persistAccount(phoneNumber: self.welcomeViewModel.phoneNumber)
            self.showCameraForPhoneAccount()
        }
        welcomeViewModel.onGoogleRequested = { [weak self] in
            Task { [weak self] in
                await self?.signInWithGoogle()
            }
        }
    }

    // Creates the camera view model and binds its navigation callbacks.
    private func makeCameraViewModel() -> PrototypeCameraViewModel {
        let viewModel = PrototypeCameraViewModel()
        viewModel.onBackRequested = { [weak self] in
            self?.showWelcome()
        }
        viewModel.onCaptureRequested = { [weak self] in
            self?.showVoicePrompt()
        }
        return viewModel
    }

    // Creates the voice view model and binds its stage-specific flow callbacks.
    private func makeVoiceViewModel() -> PrototypeVoiceViewModel {
        let viewModel = PrototypeVoiceViewModel(featureFlags: featureFlags)
        viewModel.onBackRequested = { [weak self] in
            self?.handleVoiceBackRequested()
        }
        viewModel.onStartRecordingRequested = { [weak self] in
            self?.showVoiceRecording()
        }
        viewModel.onStopRecordingRequested = { [weak self] in
            self?.showVoiceComplete()
        }
        viewModel.onRestartRequested = { [weak self] in
            self?.showVoicePrompt()
        }
        viewModel.onConfirmRequested = { [weak self] in
            self?.completeVoiceStep()
        }
        return viewModel
    }

    // Creates the success view model and binds post-onboarding actions.
    private func makeSuccessViewModel() -> PrototypeSuccessViewModel {
        let viewModel = PrototypeSuccessViewModel()
        viewModel.onCloseRequested = { [weak self] in
            self?.resetFlow()
        }
        viewModel.onOpenMessagesRequested = { [weak self] in
            self?.showMessages()
        }
        return viewModel
    }

    // Creates the messages view model and binds navigation into settings.
    private func makeMessagesViewModel() -> PrototypeMessagesViewModel {
        let viewModel = PrototypeMessagesViewModel(featureFlags: featureFlags)
        viewModel.onBackRequested = { [weak self] in
            self?.showSuccess()
        }
        viewModel.onOpenProviderSettingsRequested = { [weak self] in
            self?.showProviderSettings()
        }
        viewModel.onRetrainVoiceRequested = { [weak self] in
            Task { [weak self] in
                await self?.showVoiceRetraining()
            }
        }
        return viewModel
    }

    // Creates the provider settings view model and binds sign-out handling.
    private func makeProviderSettingsViewModel() -> PrototypeProviderSettingsViewModel {
        let viewModel = PrototypeProviderSettingsViewModel()
        viewModel.onBackRequested = { [weak self] in
            self?.showMessages()
        }
        viewModel.onSignedOut = { [weak self] in
            self?.handleSignOut()
        }
        return viewModel
    }

    private func showWelcome() {
        route = .welcome
    }

    private func showCamera() {
        route = .camera
    }

    private func showCameraForPhoneAccount() {
        guard welcomeViewModel.canContinue else { return }
        route = .camera
    }

    // Propagates the generated avatar into downstream screens before entering the voice step.
    private func showVoicePrompt() {
        let generatedAvatar = cameraViewModel.generatedAvatarImage
        
        voiceViewModel.setAvatarImage(generatedAvatar)
        successViewModel.setAvatarImage(generatedAvatar)
        messagesViewModel.setAvatarImage(generatedAvatar)

        guard featureFlags.isEnabled(.voiceUIFlow) else {
            completeVoiceStep()
            return
        }
        
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

    private func showVoiceRetraining() async {
        isRetrainingVoiceProfile = true
        await clearStoredVoiceProfileSelection()
        voiceViewModel.prepareForRetraining(
            baseProfileID: nil,
            avatarImage: messagesViewModel.avatarImage
        )
        route = .voice(.prompt)
    }

    private func clearStoredVoiceProfileSelection() async {
        sessionStore.saveVoiceProfileID(nil)
        messagesViewModel.setVoiceProfileID(nil)
        await messagesViewModel.saveConversationNow()
    }

    private func handleVoiceBackRequested() {
        if isRetrainingVoiceProfile {
            isRetrainingVoiceProfile = false
            showMessages()
        } else {
            showCamera()
        }
    }

    // Persists the trained voice profile and advances the user into the success state.
    private func completeVoiceStep() {
        pendingTransitionTask?.cancel()
        isProcessing = false
        let shouldReturnToMessages = isRetrainingVoiceProfile
        isRetrainingVoiceProfile = false
        let trainedVoiceProfileID = voiceViewModel.trainedVoiceProfileID
        sessionStore.saveVoiceProfileID(trainedVoiceProfileID)
        messagesViewModel.setVoiceProfileID(trainedVoiceProfileID)
        Task { [weak self] in
            await self?.messagesViewModel.saveConversationNow()
        }
        if shouldReturnToMessages {
            showMessages()
        } else {
            showSuccess()
        }
    }

    private func showSuccess() {
        route = .success
    }

    // Restores any saved voice profile and prepares the conversation after navigation.
    private func showMessages() {
        if let savedVoiceProfileID = sessionStore.state.voiceProfileID, !savedVoiceProfileID.isEmpty {
            messagesViewModel.setVoiceProfileID(savedVoiceProfileID)
        }
        route = .messages
        Task { [weak self] in
            await self?.messagesViewModel.prepareConversation()
        }
    }

    private func showProviderSettings() {
        guard featureFlags.isEnabled(.enableVoiceChat) else { return }
        route = .providerSettings
    }

    // Resets transient flow state while preserving any persisted session-backed defaults.
    private func resetFlow() {
        pendingTransitionTask?.cancel()
        isProcessing = false
        let sessionState = sessionStore.state
        route = Self.defaultRoute(for: sessionState)
        isRetrainingVoiceProfile = false
        welcomeViewModel.reset(phoneNumber: sessionState.phoneNumber)
        voiceViewModel.reset()
        successViewModel.setAvatarImage(nil)
        messagesViewModel.reset()
    }

    private static func defaultRoute(for sessionState: PrototypeSessionState) -> PrototypeRoute {
        if let voiceProfileID = sessionState.voiceProfileID, !voiceProfileID.isEmpty {
            return .messages
        }
        return .welcome
    }

    private func handleSignOut() {
        refreshAuthenticatedDependencies()
        route = .welcome
        welcomeViewModel.reset(phoneNumber: sessionStore.state.phoneNumber)
    }

    // Clears auth-dependent cached view models so they are rebuilt with fresh session state.
    private func refreshAuthenticatedDependencies() {
        storedVoiceViewModel = nil
        storedMessagesViewModel = nil
        storedProviderSettingsViewModel = nil
    }

    // Runs the Google sign-in flow and updates coordinator state from the resulting session.
    private func signInWithGoogle() async {
        guard let googleAuthService else {
            welcomeViewModel.presentAuthError(String(localized: AppStrings.welcomeGoogleUnavailable))
            return
        }

        guard !welcomeViewModel.isAuthenticating else { return }
        welcomeViewModel.setAuthenticating(true)

        do {
            let session = try await googleAuthService.signInWithGoogle()
            appSessionStore.save(session)
            refreshAuthenticatedDependencies()
            welcomeViewModel.clearAuthError()
            welcomeViewModel.setAuthenticating(false)
            showCamera()
        } catch PrototypeGoogleAuthError.cancelled {
            welcomeViewModel.setAuthenticating(false)
        } catch {
            welcomeViewModel.presentAuthError(
                error.localizedDescription.isEmpty
                    ? String(localized: AppStrings.welcomeGoogleAuthFailed)
                    : error.localizedDescription
            )
        }
    }
}
