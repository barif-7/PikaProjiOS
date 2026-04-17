import SwiftUI

@MainActor
final class PrototypeWelcomeViewModel: ObservableObject {
    @Published var phoneNumber = ""

    var onContinueRequested: (() -> Void)?

    let title = AppStrings.welcomeTitle
    let subtitle = AppStrings.welcomeSubtitle
    var canContinue: Bool {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).count >= 7
    }

    func continueTapped() {
        guard canContinue else { return }
        onContinueRequested?()
    }

    func reset() {
        phoneNumber = ""
    }
}
