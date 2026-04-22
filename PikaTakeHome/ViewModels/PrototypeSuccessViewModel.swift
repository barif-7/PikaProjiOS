//
//  PrototypeSuccessViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// View model for the AI-self completion screen.
@MainActor
final class PrototypeSuccessViewModel: ObservableObject {
    @Published private(set) var identityCard = PrototypeIdentityCard()

    var onCloseRequested: (() -> Void)?
    var onOpenMessagesRequested: (() -> Void)?

    let title = AppStrings.successTitle
    let subtitle = AppStrings.successSubtitle

    func closeTapped() {
        onCloseRequested?()
    }

    func openMessagesTapped() {
        onOpenMessagesRequested?()
    }

    func setAvatarImage(_ image: UIImage?) {
        identityCard.avatarImage = image
    }
}
