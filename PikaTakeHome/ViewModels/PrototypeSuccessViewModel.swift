import SwiftUI

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
