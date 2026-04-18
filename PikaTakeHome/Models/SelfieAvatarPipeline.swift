import Foundation
import UIKit
@preconcurrency import Vision

enum SelfieAvatarError: LocalizedError, Equatable {
    case notSupported
    case noFaceDetected
    case cropFailed
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Image Playground is not supported on this device."
        case .noFaceDetected:
            return "No face was found in the selected image."
        case .cropFailed:
            return "Face crop failed."
        case .invalidImageData:
            return "Image data could not be prepared."
        }
    }
}

struct PreparedSelfieAvatarInput {
    let sourceImage: UIImage
    let sourceImageURL: URL
    let croppedFace: UIImage
}

struct FaceSelection {
    static func largestFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        observations.max { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }
    }
}

struct FaceCropper {
    static func cropRect(
        for boundingBox: CGRect,
        imageSize: CGSize,
        paddingFactor: CGFloat = 0.35
    ) -> CGRect {
        let faceRect = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.maxY) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        let side = max(faceRect.width, faceRect.height) * (1 + (paddingFactor * 2))
        var cropRect = CGRect(
            x: faceRect.midX - (side / 2),
            y: faceRect.midY - (side / 2),
            width: side,
            height: side
        )

        cropRect.origin.x = max(0, cropRect.origin.x)
        cropRect.origin.y = max(0, cropRect.origin.y)

        if cropRect.maxX > imageSize.width {
            cropRect.origin.x = max(0, imageSize.width - cropRect.width)
        }
        if cropRect.maxY > imageSize.height {
            cropRect.origin.y = max(0, imageSize.height - cropRect.height)
        }

        cropRect.size.width = min(cropRect.width, imageSize.width)
        cropRect.size.height = min(cropRect.height, imageSize.height)

        return cropRect.integral
    }

    static func cropFace(
        from image: UIImage,
        boundingBox: CGRect,
        paddingFactor: CGFloat = 0.35
    ) -> UIImage? {
        guard let cgImage = image.normalizedCGImage else { return nil }

        let rect = cropRect(
            for: boundingBox,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height),
            paddingFactor: paddingFactor
        )

        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}

protocol SelfieAvatarPreparing {
    func prepareSelfie(from selfie: UIImage) async throws -> PreparedSelfieAvatarInput
}

struct SelfieAvatarService: SelfieAvatarPreparing {
    func prepareSelfie(from selfie: UIImage) async throws -> PreparedSelfieAvatarInput {
        let normalizedImage = try selfie.normalizedImage()
        let face = try await detectPrimaryFace(in: normalizedImage)

        guard let croppedFace = FaceCropper.cropFace(from: normalizedImage, boundingBox: face.boundingBox) else {
            throw SelfieAvatarError.cropFailed
        }

        let sourceImage = FaceCropper.cropFace(
            from: normalizedImage,
            boundingBox: face.boundingBox,
            paddingFactor: 0.8
        ) ?? normalizedImage

        let sourceImageURL = try writePreparedSourceJPEG(for: sourceImage)

        return PreparedSelfieAvatarInput(sourceImage: sourceImage, sourceImageURL: sourceImageURL, croppedFace: croppedFace)
    }

    private func detectPrimaryFace(in image: UIImage) async throws -> VNFaceObservation {
        guard let cgImage = image.normalizedCGImage else {
            throw SelfieAvatarError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let faces = (request.results as? [VNFaceObservation]) ?? []
                guard let face = FaceSelection.largestFace(from: faces) else {
                    continuation.resume(throwing: SelfieAvatarError.noFaceDetected)
                    return
                }

                continuation.resume(returning: face)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func writePreparedSourceJPEG(for image: UIImage) throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.96) else {
            throw SelfieAvatarError.invalidImageData
        }

        let fileManager = FileManager.default
        let directory = try selfiePromptDirectory(using: fileManager)

        let url = directory
            .appendingPathComponent("pika-selfie-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        try data.write(to: url, options: .atomic)
        return url
    }

    private func selfiePromptDirectory(using fileManager: FileManager) throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = baseDirectory
            .appendingPathComponent("PikaTakeHome", isDirectory: true)
            .appendingPathComponent("ImagePlaygroundSource", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        try? normalizedImage().cgImage
    }

    func normalizedImage() throws -> UIImage {
        if imageOrientation == .up, let cgImage {
            return UIImage(cgImage: cgImage)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        guard rendered.cgImage != nil else {
            throw SelfieAvatarError.invalidImageData
        }

        return rendered
    }
}
