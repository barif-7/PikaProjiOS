//
//  PrototypeAuthenticatorTwoFactorService.swift
//  PikaTakeHome
//
//  Created by Codex on 5/6/26.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Security
import SwiftOTP
import UIKit

struct PrototypeTwoFactorStatus {
    let isEnabled: Bool
    let manualEntryKey: String?
    let provisioningURL: URL?
    let qrCodeImage: UIImage?
}

enum PrototypeTwoFactorError: LocalizedError {
    case unavailable
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: AppStrings.twoFactorUnavailable)
        case .invalidCode:
            return String(localized: AppStrings.twoFactorInvalidCode)
        }
    }
}

protocol PrototypeTwoFactorServicing {
    func status(for user: PrototypeAuthenticatedUser?) -> PrototypeTwoFactorStatus
    func beginEnrollment(for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus
    func confirmEnrollment(code: String, for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus
    func verify(code: String, for user: PrototypeAuthenticatedUser) throws
    func disable(for user: PrototypeAuthenticatedUser)
}

struct PrototypeTwoFactorServiceFactory {
    static func makeDefault() -> PrototypeTwoFactorServicing {
        PrototypeAuthenticatorTwoFactorService()
    }
}

final class PrototypeAuthenticatorTwoFactorService: PrototypeTwoFactorServicing {
    private enum Constants {
        static let service = "com.openclaw.pikatakehome.two-factor"
        static let issuer = "Pika TakeHome"
        static let digits = 6
        static let timeInterval = 30
        static let qrCodeScale = 10.0
        static let secretLength = 20
    }

    private let qrContext = CIContext()

    func status(for user: PrototypeAuthenticatedUser?) -> PrototypeTwoFactorStatus {
        guard let user, let configuration = loadConfiguration(for: user) else {
            return PrototypeTwoFactorStatus(
                isEnabled: false,
                manualEntryKey: nil,
                provisioningURL: nil,
                qrCodeImage: nil
            )
        }
        return makeStatus(from: configuration)
    }

    func beginEnrollment(for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus {
        let configuration = TwoFactorConfiguration(
            userID: user.userID,
            accountName: displayName(for: user),
            secret: Self.generateSecret(length: Constants.secretLength),
            isEnabled: false
        )
        try save(configuration, for: user)
        return makeStatus(from: configuration)
    }

    func confirmEnrollment(code: String, for user: PrototypeAuthenticatedUser) throws -> PrototypeTwoFactorStatus {
        guard var configuration = loadConfiguration(for: user) else {
            throw PrototypeTwoFactorError.unavailable
        }
        guard validate(code: code, secret: configuration.secret) else {
            throw PrototypeTwoFactorError.invalidCode
        }
        configuration.isEnabled = true
        try save(configuration, for: user)
        return makeStatus(from: configuration)
    }

    func verify(code: String, for user: PrototypeAuthenticatedUser) throws {
        guard let configuration = loadConfiguration(for: user), configuration.isEnabled else {
            throw PrototypeTwoFactorError.unavailable
        }
        guard validate(code: code, secret: configuration.secret) else {
            throw PrototypeTwoFactorError.invalidCode
        }
    }

    func disable(for user: PrototypeAuthenticatedUser) {
        KeychainTwoFactorVault.delete(service: Constants.service, account: keychainAccount(for: user))
    }

    private func makeStatus(from configuration: TwoFactorConfiguration) -> PrototypeTwoFactorStatus {
        let provisioningURL = makeProvisioningURL(for: configuration)
        return PrototypeTwoFactorStatus(
            isEnabled: configuration.isEnabled,
            manualEntryKey: configuration.secret,
            provisioningURL: provisioningURL,
            qrCodeImage: provisioningURL.flatMap(makeQRCode(for:))
        )
    }

    private func validate(code: String, secret: String) -> Bool {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count == Constants.digits, let secretData = base32DecodeToData(secret) else {
            return false
        }
        guard let totp = TOTP(
            secret: secretData,
            digits: Constants.digits,
            timeInterval: Constants.timeInterval,
            algorithm: .sha1
        ) else {
            return false
        }

        let now = Date()
        let candidateTimes = [-Constants.timeInterval, 0, Constants.timeInterval]
        return candidateTimes.contains { offset in
            totp.generate(time: now.addingTimeInterval(TimeInterval(offset))) == normalizedCode
        }
    }

    private func makeProvisioningURL(for configuration: TwoFactorConfiguration) -> URL? {
        let label = "\(Constants.issuer):\(configuration.accountName)"
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = "/\(label ?? configuration.accountName)"
        components.queryItems = [
            URLQueryItem(name: "secret", value: configuration.secret),
            URLQueryItem(name: "issuer", value: Constants.issuer),
            URLQueryItem(name: "digits", value: String(Constants.digits)),
            URLQueryItem(name: "period", value: String(Constants.timeInterval))
        ]
        return components.url
    }

    private func makeQRCode(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: Constants.qrCodeScale, y: Constants.qrCodeScale)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = qrContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func displayName(for user: PrototypeAuthenticatedUser) -> String {
        user.email.nilIfBlank ?? user.displayName.nilIfBlank ?? user.userID
    }

    private func keychainAccount(for user: PrototypeAuthenticatedUser) -> String {
        "two-factor-\(user.userID)"
    }

    private func loadConfiguration(for user: PrototypeAuthenticatedUser) -> TwoFactorConfiguration? {
        guard let data = KeychainTwoFactorVault.load(service: Constants.service, account: keychainAccount(for: user)) else {
            return nil
        }
        return try? JSONDecoder().decode(TwoFactorConfiguration.self, from: data)
    }

    private func save(_ configuration: TwoFactorConfiguration, for user: PrototypeAuthenticatedUser) throws {
        let data = try JSONEncoder().encode(configuration)
        KeychainTwoFactorVault.save(data, service: Constants.service, account: keychainAccount(for: user))
    }

    private static func generateSecret(length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var generator = SystemRandomNumberGenerator()
        return String((0 ..< length).map { _ in alphabet.randomElement(using: &generator)! })
    }
}

private struct TwoFactorConfiguration: Codable {
    let userID: String
    let accountName: String
    let secret: String
    var isEnabled: Bool
}

private enum KeychainTwoFactorVault {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
