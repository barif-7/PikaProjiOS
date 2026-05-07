//
//  AuthConfigurationTests.swift
//  PikaTakeHomeTests
//
//  Created by Codex on 5/6/26.
//

import XCTest
@testable import PikaTakeHome

final class AuthConfigurationTests: XCTestCase {
    func testInfoPlistContainsGoogleAuthValues() throws {
        let infoDictionary = try XCTUnwrap(Self.infoPlistDictionary())

        XCTAssertEqual(
            infoDictionary["AuthBaseURL"] as? String,
            "https://pika-voice-backend-jf7rk4l2gq-pd.a.run.app"
        )
        XCTAssertEqual(infoDictionary["AuthRedirectScheme"] as? String, "pikatakehome")
    }

    func testGoogleStartURLIncludesMobileCallback() throws {
        let configuration = AuthBackendConfiguration(
            baseURL: try XCTUnwrap(URL(string: "https://pika-voice-backend-jf7rk4l2gq-pd.a.run.app")),
            callbackScheme: "pikatakehome",
            callbackURL: nil
        )

        let callbackURL = try XCTUnwrap(URL(string: "pikatakehome://auth/google"))
        let startURL = configuration.googleStartURL(mobileCallbackURL: callbackURL)
        let components = try XCTUnwrap(URLComponents(url: startURL, resolvingAgainstBaseURL: false))

        XCTAssertEqual(startURL.host, "pika-voice-backend-jf7rk4l2gq-pd.a.run.app")
        XCTAssertEqual(startURL.path, "/auth/google/start")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "mobile_callback" })?.value,
            callbackURL.absoluteString
        )
    }

    private static func infoPlistDictionary() -> NSDictionary? {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        let infoPlistURL = projectRoot
            .appendingPathComponent("PikaTakeHome")
            .appendingPathComponent("Info.plist")
        return NSDictionary(contentsOf: infoPlistURL)
    }
}
