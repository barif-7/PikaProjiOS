@preconcurrency import AVFoundation
import ImagePlayground
import SwiftUI
import UIKit

struct CameraScreen: View {
    @ObservedObject var viewModel: PrototypeCameraViewModel
    @Environment(\.designSystem) private var designSystem
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = SelfieCameraController()
    @State private var alertMessage: CameraAlertMessage?

    var body: some View {
        ZStack {
            designSystem.colors.cameraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PrototypeTopBar(
                    foregroundStyle: .white,
                    buttonBackground: Color.black.opacity(0.28)
                ) {
                    viewModel.backTapped()
                }
                .padding(.horizontal, designSystem.spacing.cameraChromeHorizontal)
                .padding(.top, designSystem.spacing.sm)

                Spacer(minLength: 8)

                SelfieCameraPreviewCard(camera: camera, viewModel: viewModel)
                    .padding(.horizontal, designSystem.spacing.cameraChromeHorizontal)
                    .frame(maxHeight: 680)

                Spacer()

                cameraControls
                    .padding(.bottom, designSystem.spacing.xl)
            }
        }
        .task {
            camera.onCapture = { image in
                Task {
                    await viewModel.processSelfie(image)
                }
            }
            camera.onError = { message in
                alertMessage = message
            }
            await camera.prepare()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                camera.startIfPossible()
            case .inactive, .background:
                camera.stop()
            @unknown default:
                camera.stop()
            }
        }
        .alert(item: $alertMessage) { message in
            if message.opensSettings {
                Alert(
                    title: Text(message.title),
                    message: Text(message.body),
                    primaryButton: .default(Text(message.actionTitle ?? "")) {
                        camera.openSettings()
                    },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(
                    title: Text(message.title),
                    message: Text(message.body),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .alert(item: $viewModel.alert) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.acknowledgeAlert()
                }
            )
        }
        .modifier(SelfieImagePlaygroundPresenter(viewModel: viewModel))
    }

    private var cameraControls: some View {
        HStack {
            Spacer()

            Button(action: { camera.capturePhoto() }) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)

                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .frame(width: 92, height: 92)
                        .opacity(0.9)
                }
            }
            .buttonStyle(.plain)
            .disabled(!camera.canCapture || viewModel.avatarState == .loading)
            .opacity((camera.canCapture && viewModel.avatarState != .loading) ? 1 : 0.7)

            Spacer()
        }
        .padding(.horizontal, designSystem.spacing.cameraControlsHorizontal)
    }
}

private struct SelfieImagePlaygroundPresenter: ViewModifier {
    @ObservedObject var viewModel: PrototypeCameraViewModel

    func body(content: Content) -> some View {
        guard #available(iOS 18.1, *), let request = viewModel.imagePlaygroundRequest else {
            return AnyView(content)
        }

        let presented = content.imagePlaygroundSheet(
            isPresented: $viewModel.isPresentingImagePlayground,
            sourceImageURL: request.sourceImageURL,
            onCompletion: { generatedImageURL in
                guard let data = try? Data(contentsOf: generatedImageURL),
                      let image = UIImage(data: data) else {
                    viewModel.imagePlaygroundFailed()
                    return
                }

                viewModel.imagePlaygroundCompleted(with: image)
            },
            onCancellation: {
                viewModel.imagePlaygroundCancelled()
            }
        )

        if #available(iOS 18.4, *) {
            return AnyView(
                presented
                    .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])
                    .imagePlaygroundPersonalizationPolicy(.enabled)
            )
        }

        return AnyView(presented)
    }
}

private struct SelfieCameraPreviewCard: View {
    @ObservedObject var camera: SelfieCameraController
    @ObservedObject var viewModel: PrototypeCameraViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.13),
                            Color(red: 0.18, green: 0.13, blue: 0.12),
                            Color(red: 0.10, green: 0.10, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if camera.isPreviewReady {
                FrontCameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(alignment: .top) {
                        previewMask
                    }
            } else {
                placeholder
            }
        }
        .overlay {
            if camera.isCapturing {
                Color.white.opacity(0.14)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
        .overlay {
            stateOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .softShadow()
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
            Text(camera.placeholderText)
                .font(AppFont.telka(15))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewMask: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.10),
                Color.clear,
                Color.black.opacity(0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.avatarState {
        case .idle:
            EmptyView()
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(AppStrings.cameraLoading)
                    .font(AppFont.telka(15, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .success:
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.green)
                Text(AppStrings.cameraSuccess)
                    .font(AppFont.telka(15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct FrontCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        if let connection = uiView.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}

private struct CameraAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let actionTitle: String?
    let opensSettings: Bool
}

private final class SelfieCameraController: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var isPreviewReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var placeholderText = ""

    let session = AVCaptureSession()

    var onCapture: ((UIImage) -> Void)?
    var onError: ((CameraAlertMessage) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.openclaw.pika.selfie-camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var isRunning = false

    var canCapture: Bool {
        isPreviewReady && !isCapturing
    }

    @MainActor
    func prepare() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            placeholderText = ""
            await configureIfNeeded()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                placeholderText = ""
                await configureIfNeeded()
            } else {
                handlePermissionDenied()
            }
        case .denied, .restricted:
            handlePermissionDenied()
        @unknown default:
            handlePermissionDenied()
        }
    }

    @MainActor
    func startIfPossible() {
        guard isConfigured, !isRunning else { return }

        let session = session
        sessionQueue.async { [weak self, session] in
            guard let self else { return }
            session.startRunning()
            let running = session.isRunning

            Task { @MainActor [weak self] in
                self?.isRunning = running
            }
        }
    }

    @MainActor
    func stop() {
        guard isRunning else { return }

        let session = session
        sessionQueue.async { [weak self, session] in
            guard let self else { return }
            session.stopRunning()

            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    @MainActor
    func capturePhoto() {
        guard canCapture else { return }

        isCapturing = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        let photoOutput = photoOutput
        sessionQueue.async { [weak self, photoOutput, settings] in
            guard let self else { return }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    @MainActor
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func configureIfNeeded() async {
        guard !isConfigured else {
            startIfPossible()
            isPreviewReady = true
            return
        }

        let configured = await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.configureSession())
            }
        }

        if configured {
            isConfigured = true
            isPreviewReady = true
            startIfPossible()
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async { [weak self] in
                self?.placeholderText = String(localized: "prototype.camera.unavailable")
                self?.onError?(
                    CameraAlertMessage(
                        title: String(localized: "prototype.camera.unavailable"),
                        body: String(localized: "prototype.camera.unavailable_body"),
                        actionTitle: nil,
                        opensSettings: false
                    )
                )
            }
            return false
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            return false
        }

        session.addOutput(photoOutput)
        if let maxDimensions = largestPhotoDimensions(for: device) {
            photoOutput.maxPhotoDimensions = maxDimensions
        }

        if let connection = photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        return true
    }

    private func largestPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        device.activeFormat.supportedMaxPhotoDimensions.max { lhs, rhs in
            Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
        }
    }

    @MainActor
    private func handlePermissionDenied() {
        placeholderText = String(localized: "prototype.camera.permission_body")
        onError?(
            CameraAlertMessage(
                title: String(localized: "prototype.camera.permission_title"),
                body: String(localized: "prototype.camera.permission_body"),
                actionTitle: String(localized: "prototype.camera.permission_action"),
                opensSettings: true
            )
        )
    }
}

extension SelfieCameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCapturing = false
                self.onError?(
                    CameraAlertMessage(
                        title: String(localized: AppStrings.cameraCaptureFailedTitle),
                        body: error.localizedDescription,
                        actionTitle: nil,
                        opensSettings: false
                    )
                )
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCapturing = false
                self.onError?(
                    CameraAlertMessage(
                        title: String(localized: AppStrings.cameraCaptureFailedTitle),
                        body: String(localized: AppStrings.cameraCaptureFailedBody),
                        actionTitle: nil,
                        opensSettings: false
                    )
                )
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isCapturing = false
            self.onCapture?(image)
        }
    }
}
