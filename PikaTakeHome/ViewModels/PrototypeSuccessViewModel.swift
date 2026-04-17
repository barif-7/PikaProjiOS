import SwiftUI

@MainActor
final class PrototypeSuccessViewModel: ObservableObject {
    let identityCard = PrototypeIdentityCard()

    var onCloseRequested: (() -> Void)?

    let title = AppStrings.successTitle
    let subtitle = AppStrings.successSubtitle

    func closeTapped() {
        onCloseRequested?()
    }
}
