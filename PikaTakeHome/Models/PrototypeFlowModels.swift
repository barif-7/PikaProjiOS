import SwiftUI

enum PrototypeRoute: Equatable {
    case welcome
    case camera
    case voice(PrototypeVoiceStage)
    case success
}

enum PrototypeVoiceStage: Equatable {
    case prompt
    case recording
    case complete
}

enum AppStrings {
    static let welcomeTitle = LocalizedStringResource("prototype.welcome.title")
    static let welcomeSubtitle = LocalizedStringResource("prototype.welcome.subtitle")
    static let welcomeContinue = LocalizedStringResource("prototype.welcome.continue")
    static let welcomeTerms = LocalizedStringResource("prototype.welcome.terms")
    static let phoneNumberPlaceholder = LocalizedStringResource("prototype.welcome.phone_placeholder")
    static let continueWith = LocalizedStringResource("prototype.shared.continue_with")

    static let voiceTitle = LocalizedStringResource("prototype.voice.title")
    static let voiceSubtitle = LocalizedStringResource("prototype.voice.subtitle")
    static let voiceQuote = LocalizedStringResource("prototype.voice.quote")
    static let voiceListening = LocalizedStringResource("prototype.voice.listening")

    static let successTitle = LocalizedStringResource("prototype.success.title")
    static let successSubtitle = LocalizedStringResource("prototype.success.subtitle")
    static let successOpenMessages = LocalizedStringResource("prototype.success.open_messages")
    static let successShareIDCard = LocalizedStringResource("prototype.success.share_id_card")

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
}
