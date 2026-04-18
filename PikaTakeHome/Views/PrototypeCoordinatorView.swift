import SwiftUI

struct PrototypeCoordinatorView: View {
    @ObservedObject var coordinator: PrototypeCoordinator

    var body: some View {
        ZStack {
            currentScreen
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: coordinator.animationValue)
        .overlay {
            if coordinator.isProcessing {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()

                ProgressView()
                    .padding(16)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch coordinator.route {
        case .welcome:
            WelcomeScreen(viewModel: coordinator.welcomeViewModel)
        case .camera:
            CameraScreen(viewModel: coordinator.cameraViewModel)
        case .voice:
            VoiceScreen(viewModel: coordinator.voiceViewModel)
        case .success:
            SuccessScreen(viewModel: coordinator.successViewModel)
        case .messages:
            MessagesScreen(viewModel: coordinator.messagesViewModel)
        }
    }
}
