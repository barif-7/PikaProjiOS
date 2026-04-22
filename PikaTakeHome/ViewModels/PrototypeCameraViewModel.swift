//
//  PrototypeCameraViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI
import UIKit
import ImagePlayground

/// View model for selfie capture and AI avatar preparation.
@MainActor
final class PrototypeCameraViewModel: ObservableObject {
    @Published private(set) var avatarState: PrototypeCameraAvatarState = .idle
    @Published var alert: PrototypeCameraAlert?
    @Published private(set) var imagePlaygroundRequest: ImagePlaygroundRequest?
    @Published var isPresentingImagePlayground = false
    @Published private(set) var generatedAvatarImage: UIImage?
    @Published private(set) var croppedFaceImage: UIImage?
    @Published private(set) var statusMessage: LocalizedStringResource?

    var onBackRequested: (() -> Void)?
    var onCaptureRequested: (() -> Void)?

    private let avatarService: SelfieAvatarPreparing

    init(avatarService: SelfieAvatarPreparing = SelfieAvatarService()) {
        self.avatarService = avatarService
    }

    /// File-backed request that can be presented to Image Playground.
    struct ImagePlaygroundRequest: Equatable {
        let sourceImageURL: URL
    }

    func backTapped() {
        onBackRequested?()
    }

    /// Validates the selected selfie, prepares a cropped prompt image, and presents Image Playground.
    func processSelfie(_ image: UIImage) async {
        guard avatarState != .loading else { return }

        avatarState = .loading
        alert = nil
        statusMessage = nil
        generatedAvatarImage = nil

        do {
            let result = try await avatarService.prepareSelfie(from: image)
            croppedFaceImage = result.croppedFace

            guard imagePlaygroundIsAvailable else {
                avatarState = .idle
                alert = map(error: .notSupported)
                return
            }

            imagePlaygroundRequest = try makeImagePlaygroundRequest(from: result)
            await Task.yield()
            isPresentingImagePlayground = true
        } catch let error as SelfieAvatarError {
            avatarState = .idle
            alert = map(error: error)
        } catch {
            avatarState = .idle
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.cameraAvatarGenerationFailedTitle),
                message: String(localized: AppStrings.cameraAvatarGenerationFailedBody)
            )
        }
    }

    func useDefaultAvatarImage() {
        guard avatarState != .loading else { return }

        guard let defaultAvatarImage = BitmapImageStore.shared.image(for: .semiPortrait) else {
            avatarState = .idle
            alert = PrototypeCameraAlert(
                title: String(localized: AppStrings.cameraAvatarGenerationFailedTitle),
                message: String(localized: AppStrings.cameraAvatarGenerationFailedBody)
            )
            return
        }

        generatedAvatarImage = defaultAvatarImage
        croppedFaceImage = nil
        statusMessage = AppStrings.cameraFrontCameraPlaceholder
        avatarState = .success
        clearImagePlaygroundState()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            self?.onCaptureRequested?()
        }
    }

    func acknowledgeAlert() {
        alert = nil
    }

    func imagePlaygroundCompleted(with image: UIImage) {
        generatedAvatarImage = image
        statusMessage = nil
        avatarState = .success
        clearImagePlaygroundState()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.onCaptureRequested?()
        }
    }

    func imagePlaygroundCancelled() {
        avatarState = .idle
        statusMessage = nil
        clearImagePlaygroundState()
        alert = PrototypeCameraAlert(
            title: String(localized: AppStrings.cameraAvatarGenerationFailedTitle),
            message: String(localized: AppStrings.cameraCancelledBody)
        )
    }

    func imagePlaygroundFailed() {
        avatarState = .idle
        statusMessage = nil
        clearImagePlaygroundState()
        alert = PrototypeCameraAlert(
            title: String(localized: AppStrings.cameraAvatarGenerationFailedTitle),
            message: String(localized: AppStrings.cameraAvatarGenerationFailedBody)
        )
    }

    private func map(error: SelfieAvatarError) -> PrototypeCameraAlert {
        switch error {
        case .noFaceDetected:
            return PrototypeCameraAlert(
                title: String(localized: AppStrings.cameraNoFaceTitle),
                message: String(localized: AppStrings.cameraNoFaceMessage)
            )
        case .cropFailed, .invalidImageData:
            return PrototypeCameraAlert(
                title: String(localized: AppStrings.cameraAvatarGenerationFailedTitle),
                message: String(localized: AppStrings.cameraAvatarGenerationFailedBody)
            )
        case .notSupported:
            return PrototypeCameraAlert(
                title: String(localized: AppStrings.cameraImagePlaygroundUnavailableTitle),
                message: String(localized: AppStrings.cameraImagePlaygroundUnavailableBody)
            )
        }
    }

    private func clearImagePlaygroundState() {
        imagePlaygroundRequest = nil
        isPresentingImagePlayground = false
    }

    private func makeImagePlaygroundRequest(from result: PreparedSelfieAvatarInput) throws -> ImagePlaygroundRequest {
        let sourceURL = result.sourceImageURL
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path),
              (try? sourceURL.checkResourceIsReachable()) == true else {
            throw SelfieAvatarError.invalidImageData
        }

        return ImagePlaygroundRequest(
            sourceImageURL: sourceURL
        )
    }

    private var imagePlaygroundIsAvailable: Bool {
        if #available(iOS 18.1, *) {
            return ImagePlaygroundViewController.isAvailable
        }
        return false
    }
}
