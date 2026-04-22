//
//  PikaKitTests.swift
//  PikaTakeHomeTests
//
//  Created by Basil Arif on 4/20/26.
//

import XCTest
@testable import PikaTakeHome

final class PikaKitTests: XCTestCase {
    func testPikaKitExposesDefaultProviders() {
        XCTAssertTrue(PikaKit.current.fonts is PikaFontProvider)
        XCTAssertTrue(PikaKit.current.colors is PikaColorProvider)
        XCTAssertTrue(PikaKit.current.images is PikaImageProvider)
        XCTAssertEqual(PikaSystemImage.microphone.rawValue, "mic.fill")
    }

    func testPikaKitResolvesImportedAssetPaths() {
        XCTAssertNotNil(PikaKit.Images.path(for: .voiceBackground))
    }
}
