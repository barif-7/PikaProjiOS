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

enum PrototypeCopy {
    static let welcomeTitle = "YOUR AI SELF IS WAITING"
    static let welcomeSubtitle = "Sign up or log in below"
    static let voiceTitle = "MAKE YOUR AI SELF SOUND LIKE YOU"
    static let voiceSubtitle = "Read the text below to clone your voice and create an AI Self that talks like you."
    static let voiceQuote = "My best self is just ahead. The life I've always wanted is here. My goals are in reach. I love affirmations."
    static let successTitle = "MEET SEMI"
    static let successSubtitle = "Your AI Self is ready to chat"
}

struct PrototypeIdentityCard {
    let name = "SEMI"
    let birthLabel = "BORN ON PIKA"
    let birthDate = "FEB 11, 2026"
    let location = "SAN FRANCISCO, CA"
    let status = "ALIVE"
    let profileLink = "PIKA.ME/LUNA-SMITH"
    let identifier = "SEMI // 01"
}
