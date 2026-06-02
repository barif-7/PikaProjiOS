//
//  FeatureFlags.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/21/26.
//

import Foundation

/// Flags that control staged rollout of the prototype experience.
enum FeatureFlag: String, CaseIterable {
    case voiceUIFlow = "Voice UI Flow"
    case enableVoiceTraining = "Enable Voice Training"
    case enableVoiceChat = "Enable Voice Chat"
    case enableVoiceStreaming = "Enable Voice Streaming"
    case base44DesignUpgrade = "Base44 Design Upgrade"

    var environmentKey: String {
        switch self {
        case .voiceUIFlow:
            return "PIKA_FEATURE_VOICE_UI_FLOW"
        case .enableVoiceTraining:
            return "PIKA_FEATURE_ENABLE_VOICE_TRAINING"
        case .enableVoiceChat:
            return "PIKA_FEATURE_ENABLE_VOICE_CHAT"
        case .enableVoiceStreaming:
            return "PIKA_FEATURE_ENABLE_VOICE_STREAMING"
        case .base44DesignUpgrade:
            return "PIKA_FEATURE_BASE44_DESIGN_UPGRADE"
        }
    }

    var plistKey: String {
        environmentKey
    }
}

protocol FeatureFlagManaging {
    func isEnabled(_ flag: FeatureFlag) -> Bool
}

/// Local feature flag source with environment overrides for simulator and CI runs.
struct FeatureFlagManager: FeatureFlagManaging {
    static let shared = FeatureFlagManager()

    private let overrides: [FeatureFlag: Bool]
    private let environment: [String: String]
    private let bundle: Bundle

    init(
        overrides: [FeatureFlag: Bool] = [:],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) {
        self.overrides = overrides
        self.environment = environment
        self.bundle = bundle
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if let override = overrides[flag] {
            return override
        }

        if let environmentValue = environment[flag.environmentKey],
           let parsedValue = Self.parseBoolean(environmentValue) {
            return parsedValue
        }

        if let plistValue = bundle.object(forInfoDictionaryKey: flag.plistKey),
           let parsedValue = Self.parseBoolean(plistValue) {
            return parsedValue
        }

        return Self.defaultValue(for: flag)
    }

    private static func defaultValue(for flag: FeatureFlag) -> Bool {
        switch flag {
        case .voiceUIFlow:
            return true
        case .enableVoiceTraining, .enableVoiceChat, .enableVoiceStreaming:
            return false
        case .base44DesignUpgrade:
            return true
        }
    }

    private static func parseBoolean(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on", "enabled":
            return true
        case "0", "false", "no", "n", "off", "disabled":
            return false
        default:
            return nil
        }
    }

    private static func parseBoolean(_ value: Any) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return parseBoolean(stringValue)
        }

        return nil
    }
}
