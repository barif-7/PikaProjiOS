import SwiftUI

@MainActor
final class PrototypeCameraViewModel: ObservableObject {
    var onBackRequested: (() -> Void)?
    var onCaptureRequested: (() -> Void)?

    func backTapped() {
        onBackRequested?()
    }

    func captureTapped() {
        onCaptureRequested?()
    }
}
