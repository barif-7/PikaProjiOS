//
//  PikaBackendConfiguration.swift
//  PikaTakeHome
//
//  Unified backend configuration for all Pika service calls.
//
//  Resolution order (first match wins):
//   1. PIKA_BACKEND_BASE_URL  process-info environment variable
//   2. PikaBackendBaseURL     Info.plist key
//   3. VOICE_CHAT_BASE_URL    legacy environment variable (kept for dev compatibility)
//   4. VOICE_TRAINING_BASE_URL legacy environment variable
//   5. http://127.0.0.1:8080  simulator-only fallback
//
//  API key (optional — only sent when REQUIRE_API_KEY=1 on the server):
//   1. PIKA_API_KEY            process-info environment variable
//   2. PikaAPIKey              Info.plist key
//

import Foundation

struct PikaBackendConfiguration {
    let baseURL: URL
    /// Optional service-level API key forwarded as `X-API-Key` on every request.
    let apiKey: String?

    private static let simulatorDefaultBaseURL = URL(string: "http://127.0.0.1:8080")!

    // MARK: - Factory

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> PikaBackendConfiguration? {
        let url = resolveBaseURL(bundle: bundle, processInfo: processInfo)
        guard let url else { return nil }
        let apiKey = resolveAPIKey(bundle: bundle, processInfo: processInfo)
        return PikaBackendConfiguration(baseURL: url, apiKey: apiKey)
    }

    // MARK: - URL helpers

    var voiceChatJobsURL: URL {
        baseURL.appendingPathComponent("voice-chat").appendingPathComponent("jobs")
    }

    var voiceChatTurnURL: URL {
        baseURL.appendingPathComponent("voice-chat").appendingPathComponent("turn")
    }

    func voiceChatJobStatusURL(jobID: String) -> URL {
        voiceChatJobsURL.appendingPathComponent(jobID)
    }

    var voiceProfilesURL: URL {
        baseURL.appendingPathComponent("voice-profiles")
    }

    var voiceProfileCapabilitiesURL: URL {
        voiceProfilesURL.appendingPathComponent("capabilities")
    }

    func voiceProfileStatusURL(jobID: String) -> URL {
        voiceProfilesURL.appendingPathComponent(jobID)
    }

    var audioUploadsURL: URL {
        baseURL.appendingPathComponent("audio").appendingPathComponent("uploads")
    }

    // MARK: - Request decoration

    /// Apply the API key header to a request if a key is configured.
    func decorate(_ request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
    }

    // MARK: - Private helpers

    private static func resolveBaseURL(bundle: Bundle, processInfo: ProcessInfo) -> URL? {
        let env = processInfo.environment

        // 1. New unified env var
        if let raw = env["PIKA_BACKEND_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        // 2. Info.plist key
        if let raw = (bundle.object(forInfoDictionaryKey: "PikaBackendBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        // 3. Legacy voice-chat env var
        if let raw = env["VOICE_CHAT_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        // 4. Legacy voice-training env var
        if let raw = env["VOICE_TRAINING_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        // 5. Simulator fallback
        #if targetEnvironment(simulator)
        return simulatorDefaultBaseURL
        #else
        return nil
        #endif
    }

    private static func resolveAPIKey(bundle: Bundle, processInfo: ProcessInfo) -> String? {
        if let key = processInfo.environment["PIKA_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        if let key = (bundle.object(forInfoDictionaryKey: "PikaAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        return nil
    }
}

// MARK: - Nil-if-blank helper (if not already defined elsewhere)

private extension String {
    var nilIfBlankLocal: String? { isEmpty ? nil : self }
}
