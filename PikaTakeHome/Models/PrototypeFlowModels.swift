import SwiftUI

enum PrototypeRoute: Equatable {
    case welcome
    case camera
    case voice(PrototypeVoiceStage)
    case success
    case messages
}

enum PrototypeVoiceStage: Equatable {
    case prompt
    case recording
    case complete
}

enum PrototypeCameraAvatarState: Equatable {
    case idle
    case loading
    case success
}

struct PrototypeCameraAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

enum AppStrings {
    static let welcomeTitle = LocalizedStringResource("prototype.welcome.title")
    static let welcomeSubtitle = LocalizedStringResource("prototype.welcome.subtitle")
    static let welcomeContinue = LocalizedStringResource("prototype.welcome.continue")
    static let welcomeTerms = LocalizedStringResource("prototype.welcome.terms")
    static let phoneNumberPlaceholder = LocalizedStringResource("prototype.welcome.phone_placeholder")
    static let continueWith = LocalizedStringResource("prototype.shared.continue_with")
    static let cameraLoading = LocalizedStringResource("prototype.camera.loading")
    static let cameraSuccess = LocalizedStringResource("prototype.camera.success")
    static let cameraNoFaceTitle = LocalizedStringResource("prototype.camera.no_face_title")
    static let cameraNoFaceMessage = LocalizedStringResource("prototype.camera.no_face_message")
    static let cameraMultipleFacesMessage = LocalizedStringResource("prototype.camera.multiple_faces_message")
    static let cameraCaptureFailedTitle = LocalizedStringResource("prototype.camera.capture_failed")
    static let cameraCaptureFailedBody = LocalizedStringResource("prototype.camera.capture_failed_body")
    static let cameraImagePlaygroundUnavailableTitle = LocalizedStringResource("prototype.camera.image_playground_unavailable_title")
    static let cameraImagePlaygroundUnavailableBody = LocalizedStringResource("prototype.camera.image_playground_unavailable_body")
    static let cameraAvatarGenerationFailedTitle = LocalizedStringResource("prototype.camera.avatar_generation_failed_title")
    static let cameraAvatarGenerationFailedBody = LocalizedStringResource("prototype.camera.avatar_generation_failed_body")
    static let cameraUnsupportedLanguageBody = LocalizedStringResource("prototype.camera.unsupported_language_body")
    static let cameraForegroundRequiredBody = LocalizedStringResource("prototype.camera.foreground_required_body")
    static let cameraFaceTooSmallBody = LocalizedStringResource("prototype.camera.face_too_small_body")
    static let cameraUnsupportedInputBody = LocalizedStringResource("prototype.camera.unsupported_input_body")
    static let cameraCancelledBody = LocalizedStringResource("prototype.camera.cancelled_body")
    static let cameraPickFailedTitle = LocalizedStringResource("prototype.camera.pick_failed_title")
    static let cameraPickFailedBody = LocalizedStringResource("prototype.camera.pick_failed_body")

    static let voiceTitle = LocalizedStringResource("prototype.voice.title")
    static let voiceSubtitle = LocalizedStringResource("prototype.voice.subtitle")
    static let voiceQuote = LocalizedStringResource("prototype.voice.quote")
    static let voiceListening = LocalizedStringResource("prototype.voice.listening")
    static let voicePermissionTitle = LocalizedStringResource("prototype.voice.permission_title")
    static let voicePermissionBody = LocalizedStringResource("prototype.voice.permission_body")
    static let voiceRecordingFailedTitle = LocalizedStringResource("prototype.voice.recording_failed_title")
    static let voiceRecordingFailedBody = LocalizedStringResource("prototype.voice.recording_failed_body")
    static let voiceMissingSampleTitle = LocalizedStringResource("prototype.voice.missing_sample_title")
    static let voiceMissingSampleBody = LocalizedStringResource("prototype.voice.missing_sample_body")
    static let voiceUploading = LocalizedStringResource("prototype.voice.uploading")
    static let voiceQueued = LocalizedStringResource("prototype.voice.queued")
    static let voiceTraining = LocalizedStringResource("prototype.voice.training")
    static let voiceTrainingFailedTitle = LocalizedStringResource("prototype.voice.training_failed_title")
    static let voiceTrainingFailedBody = LocalizedStringResource("prototype.voice.training_failed_body")

    static let successTitle = LocalizedStringResource("prototype.success.title")
    static let successSubtitle = LocalizedStringResource("prototype.success.subtitle")
    static let successOpenMessages = LocalizedStringResource("prototype.success.open_messages")
    static let successShareIDCard = LocalizedStringResource("prototype.success.share_id_card")

    static let messagesTitle = LocalizedStringResource("prototype.messages.title")
    static let messagesSubtitle = LocalizedStringResource("prototype.messages.subtitle")
    static let messagesStatusReady = LocalizedStringResource("prototype.messages.status_ready")
    static let messagesStatusListening = LocalizedStringResource("prototype.messages.status_listening")
    static let messagesStatusResponding = LocalizedStringResource("prototype.messages.status_responding")
    static let messagesHint = LocalizedStringResource("prototype.messages.hint")
    static let messagesStartTalking = LocalizedStringResource("prototype.messages.start_talking")
    static let messagesFinishTurn = LocalizedStringResource("prototype.messages.finish_turn")
    static let messagesEndCall = LocalizedStringResource("prototype.messages.end_call")
    static let messagesMicrophonePermissionTitle = LocalizedStringResource("prototype.messages.microphone_permission_title")
    static let messagesMicrophonePermissionBody = LocalizedStringResource("prototype.messages.microphone_permission_body")
    static let messagesSpeechPermissionTitle = LocalizedStringResource("prototype.messages.speech_permission_title")
    static let messagesSpeechPermissionBody = LocalizedStringResource("prototype.messages.speech_permission_body")
    static let messagesSpeechUnavailableBody = LocalizedStringResource("prototype.messages.speech_unavailable_body")
    static let messagesRecordingFailedTitle = LocalizedStringResource("prototype.messages.recording_failed_title")
    static let messagesRecordingFailedBody = LocalizedStringResource("prototype.messages.recording_failed_body")
    static let messagesTranscriptionFailedBody = LocalizedStringResource("prototype.messages.transcription_failed_body")
    static let messagesBackendFailedTitle = LocalizedStringResource("prototype.messages.backend_failed_title")
    static let messagesBackendFailedBody = LocalizedStringResource("prototype.messages.backend_failed_body")
    static let messagesBackendNotConfiguredBody = LocalizedStringResource("prototype.messages.backend_not_configured_body")

    static let identityBornOnPika = LocalizedStringResource("prototype.identity.born_on_pika")
    static let identityBirthDate = LocalizedStringResource("prototype.identity.birth_date")
    static let identityProfile = LocalizedStringResource("prototype.identity.profile")
    static let identityLocation = LocalizedStringResource("prototype.identity.location")
    static let identityLocationValue = LocalizedStringResource("prototype.identity.location_value")
    static let identityStatus = LocalizedStringResource("prototype.identity.status")
    static let identityStatusValue = LocalizedStringResource("prototype.identity.status_value")
    static let identityFindMeOn = LocalizedStringResource("prototype.identity.find_me_on")
    static let identityProfileLink = LocalizedStringResource("prototype.identity.profile_link")
    static let identityIdentifierLabel = LocalizedStringResource("prototype.identity.identifier_label")
}

struct PrototypeIdentityCard {
    let name = "SEMI"
    let birthLabel = AppStrings.identityBornOnPika
    let birthDate = AppStrings.identityBirthDate
    let location = AppStrings.identityLocationValue
    let status = AppStrings.identityStatusValue
    let profileLink = AppStrings.identityProfileLink
    let identifier = "SEMI // 01"
    var avatarImage: UIImage?
}
