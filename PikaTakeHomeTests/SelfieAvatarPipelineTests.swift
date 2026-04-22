//
//  SelfieAvatarPipelineTests.swift
//  PikaTakeHomeTests
//
//  Created by Basil Arif on 4/20/26.
//

import Vision
import XCTest
@testable import PikaTakeHome

final class SelfieAvatarPipelineTests: XCTestCase {
    func testLargestFaceSelectionPicksLargestArea() {
        let small = VNFaceObservation(boundingBox: CGRect(x: 0.10, y: 0.10, width: 0.20, height: 0.20))
        let medium = VNFaceObservation(boundingBox: CGRect(x: 0.20, y: 0.20, width: 0.25, height: 0.25))
        let large = VNFaceObservation(boundingBox: CGRect(x: 0.15, y: 0.15, width: 0.40, height: 0.35))

        let selected = FaceSelection.largestFace(from: [small, large, medium])

        XCTAssertEqual(selected?.boundingBox, large.boundingBox)
    }

    func testCropRectConvertsVisionCoordinatesAndPadsFace() {
        let rect = FaceCropper.cropRect(
            for: CGRect(x: 0.25, y: 0.35, width: 0.20, height: 0.30),
            imageSize: CGSize(width: 1000, height: 800),
            paddingFactor: 0.25
        )

        XCTAssertEqual(rect.origin.x, 170)
        XCTAssertEqual(rect.origin.y, 220)
        XCTAssertEqual(rect.size.width, 360)
        XCTAssertEqual(rect.size.height, 360)
    }

    func testCropRectClampsToImageBounds() {
        let rect = FaceCropper.cropRect(
            for: CGRect(x: 0.78, y: 0.04, width: 0.18, height: 0.22),
            imageSize: CGSize(width: 500, height: 500),
            paddingFactor: 0.40
        )

        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, 500)
        XCTAssertLessThanOrEqual(rect.maxY, 500)
        XCTAssertEqual(rect.width, rect.height)
    }
}
