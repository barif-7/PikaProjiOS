//
//  PrototypeSnapshotTests.swift
//  PikaTakeHomeTests
//
//  Created by Codex on 5/6/26.
//

import SwiftUI
import UIKit
import XCTest
import iOSSnapshotTestCase
@testable import PikaTakeHome

final class PrototypeSnapshotTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        let referenceDirectory = Self.referenceImagesDirectoryURL()
        let diffDirectory = Self.failureDiffsDirectoryURL()
        try? FileManager.default.createDirectory(
            at: referenceDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? FileManager.default.createDirectory(
            at: diffDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        setenv("FB_REFERENCE_IMAGE_DIR", referenceDirectory.path, 1)
        setenv("IMAGE_DIFF_DIR", diffDirectory.path, 1)
        setenv("PIKA_DISABLE_IMPORTED_ASSETS", "1", 1)

        recordMode = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
        fileNameOptions = []
    }

    @MainActor
    func testWelcomeScreen() {
        let viewModel = PrototypeWelcomeViewModel(phoneNumber: "4165550199")

        verifySnapshot(
            view: WelcomeScreen(viewModel: viewModel),
            identifier: "welcome"
        )
    }

    @MainActor
    func testActionButtonsStack() {
        verifySnapshot(
            view: VStack(spacing: 12) {
                PrimaryButton(
                    title: AppStrings.welcomeContinue,
                    enabled: true,
                    trailingAsset: .arrowTopRight,
                    action: {}
                )
                SecondaryButton(
                    title: AppStrings.successShareIDCard,
                    trailingAsset: .shareIcon,
                    action: {}
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.default.colors.screenBackground),
            identifier: "action-buttons",
            size: CGSize(width: 390, height: 220)
        )
    }

    @MainActor
    func testProviderSettingsScreenWithTwoFactorEnrollment() async {
        let sessionStore = SnapshotSessionStore(
            session: PrototypeAppSession(
                sessionToken: "session-token",
                user: PrototypeAuthenticatedUser(
                    userID: "user-123",
                    email: "semi@pika.me",
                    displayName: "Semi",
                    photoURL: nil
                ),
                expiresAt: nil
            )
        )
        let providerService = SnapshotProviderConnectionService()
        let viewModel = PrototypeProviderSettingsViewModel(
            service: providerService,
            appSessionStore: sessionStore,
            authService: nil,
            twoFactorService: SnapshotTwoFactorService(),
            serviceBuilder: SnapshotProviderServiceBuilder(service: providerService),
            authConfiguration: nil
        )
        await viewModel.prepare()
        viewModel.enableTwoFactorTapped()

        verifySnapshot(
            view: ProviderSettingsScreen(viewModel: viewModel),
            identifier: "provider-enrollment-v2"
        )
    }

    @MainActor
    func testProviderSettingsScreenVerified() async {
        let sessionStore = SnapshotSessionStore(
            session: PrototypeAppSession(
                sessionToken: "session-token",
                user: PrototypeAuthenticatedUser(
                    userID: "user-123",
                    email: "semi@pika.me",
                    displayName: "Semi",
                    photoURL: nil
                ),
                expiresAt: nil
            )
        )
        let providerService = SnapshotProviderConnectionService()
        let twoFactorService = SnapshotTwoFactorService()
        let viewModel = PrototypeProviderSettingsViewModel(
            service: providerService,
            appSessionStore: sessionStore,
            authService: nil,
            twoFactorService: twoFactorService,
            serviceBuilder: SnapshotProviderServiceBuilder(service: providerService),
            authConfiguration: nil
        )
        await viewModel.prepare()
        viewModel.enableTwoFactorTapped()
        viewModel.twoFactorCode = "123456"
        viewModel.confirmTwoFactorTapped()

        verifySnapshot(
            view: ProviderSettingsScreen(viewModel: viewModel),
            identifier: "provider-verified"
        )
    }

    @MainActor
    func testProviderSettingsScreenSignedOut() async {
        let sessionStore = SnapshotSessionStore(
            session: PrototypeAppSession(
                sessionToken: "session-token",
                user: PrototypeAuthenticatedUser(
                    userID: "user-123",
                    email: "semi@pika.me",
                    displayName: "Semi",
                    photoURL: nil
                ),
                expiresAt: nil
            )
        )
        let providerService = SnapshotProviderConnectionService()
        let viewModel = PrototypeProviderSettingsViewModel(
            service: providerService,
            appSessionStore: sessionStore,
            authService: nil,
            twoFactorService: SnapshotTwoFactorService(),
            serviceBuilder: SnapshotProviderServiceBuilder(service: providerService),
            authConfiguration: nil
        )
        await viewModel.prepare()
        await viewModel.signOut()

        verifySnapshot(
            view: ProviderSettingsScreen(viewModel: viewModel),
            identifier: "provider-signed-out"
        )
    }

    @MainActor
    private func verifySnapshot<V: View>(
        view: V,
        identifier: String,
        size: CGSize = CGSize(width: 390, height: 844)
    ) {
        let shouldRecord = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
            || !Self.referenceImageExists(for: identifier)
        recordMode = shouldRecord

        let hostingController = UIHostingController(
            rootView: view.environment(\.designSystem, DesignSystem.default)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.frame = window.bounds
        hostingController.view.backgroundColor = .clear
        hostingController.view.layoutIfNeeded()
        window.layoutIfNeeded()

        FBSnapshotVerifyView(hostingController.view, identifier: identifier)
    }

    private static func makeAvatarImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 220, height: 220))
        return renderer.image { context in
            let colors = [UIColor(red: 0.18, green: 0.12, blue: 0.42, alpha: 1), UIColor(red: 0.93, green: 0.49, blue: 0.32, alpha: 1)] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 220, y: 220),
                options: []
            )
        }
    }

    private static func referenceImagesDirectoryURL() -> URL {
        testsDirectoryURL().appendingPathComponent("ReferenceImages")
    }

    private static func failureDiffsDirectoryURL() -> URL {
        testsDirectoryURL().appendingPathComponent("FailureDiffs")
    }

    private static func testsDirectoryURL() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static func referenceImageExists(for identifier: String) -> Bool {
        let normalizedIdentifier = identifier.replacingOccurrences(of: "-", with: "_")
        guard let enumerator = FileManager.default.enumerator(
            at: testsDirectoryURL(),
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "png" {
            if fileURL.lastPathComponent.contains(normalizedIdentifier) {
                return true
            }
        }
        return false
    }
}

private final class SnapshotProviderConnectionService: PrototypeProviderConnectionServicing {
    func loadOllamaConnection() async throws -> PrototypeOllamaConnection? {
        PrototypeOllamaConnection(
            endpointURL: "https://ollama.example.com",
            model: "llama3.1",
            apiToken: "",
            label: "Local Ollama"
        )
    }

    func saveOllamaConnection(_ connection: PrototypeOllamaConnection) async throws {}
}

private struct SnapshotProviderServiceBuilder: PrototypeProviderConnectionServiceBuilding {
    let service: PrototypeProviderConnectionServicing

    @MainActor
    func makeService(
        appSessionStore: PrototypeProviderSettingsSessionStoring,
        authConfiguration: AuthBackendConfiguration?
    ) -> PrototypeProviderConnectionServicing? {
        service
    }
}

@MainActor
private final class SnapshotSessionStore: PrototypeProviderSettingsSessionStoring {
    var currentSession: PrototypeAppSession?

    init(session: PrototypeAppSession?) {
        currentSession = session
    }

    func clearSession() {
        currentSession = nil
    }
}

private final class SnapshotTwoFactorService: PrototypeTwoFactorServicing {
    private var configurations: [String: PrototypeTwoFactorStatus] = [:]

    func status(for user: PrototypeAuthenticatedUser?) -> PrototypeTwoFactorStatus {
        guard let user else {
            return PrototypeTwoFactorStatus(isEnabled: false, manualEntryKey: nil, provisioningURL: nil, qrCodeImage: nil)
        }
        return configurations[user.userID]
            ?? PrototypeTwoFactorStatus(isEnabled: false, manualEntryKey: nil, provisioningURL: nil, qrCodeImage: nil)
    }

    func beginEnrollment(for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 180)).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 180, height: 180))
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 24, y: 24, width: 48, height: 48))
            context.cgContext.fill(CGRect(x: 108, y: 24, width: 48, height: 48))
            context.cgContext.fill(CGRect(x: 24, y: 108, width: 48, height: 48))
            context.cgContext.fill(CGRect(x: 96, y: 96, width: 24, height: 24))
            context.cgContext.fill(CGRect(x: 132, y: 132, width: 24, height: 24))
        }
        let status = PrototypeTwoFactorStatus(
            isEnabled: false,
            manualEntryKey: "JBSWY3DPEHPK3PXP",
            provisioningURL: URL(string: "otpauth://totp/Pika?secret=JBSWY3DPEHPK3PXP"),
            qrCodeImage: image
        )
        configurations[user.userID] = status
        return status
    }

    func confirmEnrollment(code: String, for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus {
        let status = PrototypeTwoFactorStatus(
            isEnabled: true,
            manualEntryKey: "JBSWY3DPEHPK3PXP",
            provisioningURL: URL(string: "otpauth://totp/Pika?secret=JBSWY3DPEHPK3PXP"),
            qrCodeImage: nil
        )
        configurations[user.userID] = status
        return status
    }

    func verify(code: String, for user: PrototypeAuthenticatedUser) throws {}

    func disable(for user: PrototypeAuthenticatedUser) {
        configurations[user.userID] = PrototypeTwoFactorStatus(
            isEnabled: false,
            manualEntryKey: nil,
            provisioningURL: nil,
            qrCodeImage: nil
        )
    }
}
