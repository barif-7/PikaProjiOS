import SwiftUI

struct CameraScreen: View {
    @ObservedObject var viewModel: PrototypeCameraViewModel

    var body: some View {
        ZStack {
            AppColor.cameraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: .white,
                    buttonBackground: Color.black.opacity(0.28)
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer(minLength: 8)

                CameraPreviewCard()
                    .padding(.horizontal, 18)
                    .frame(maxHeight: 680)

                Spacer()

                CaptureControls(
                    onGallery: {},
                    onShutter: { viewModel.captureTapped() },
                    onFlip: {}
                )
                .padding(.bottom, 24)
            }
        }
    }
}
