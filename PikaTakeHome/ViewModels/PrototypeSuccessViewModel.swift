import SwiftUI

@MainActor
final class PrototypeSuccessViewModel: ObservableObject {
    let identityCard = PrototypeIdentityCard()

    var onCloseRequested: (() -> Void)?

    var title: String { PrototypeCopy.successTitle }
    var subtitle: String { PrototypeCopy.successSubtitle }

    func closeTapped() {
        onCloseRequested?()
    }
}
