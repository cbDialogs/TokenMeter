import Foundation
import Observation

/// Reads Claude Code's OAuth token from the Keychain and polls the usage endpoint.
///
/// The token is never refreshed here: refreshing would rotate Claude Code's
/// refresh token. When it expires, running `claude` refreshes it and the next
/// poll picks up the new one.
@MainActor
@Observable
final class UsageService {
    static let modelName = "Fable"
    static let pollInterval: TimeInterval = 120

    private(set) var modelPercent: Double?
    private(set) var modelResetsAt: Date?
    private(set) var sessionPercent: Double?
    private(set) var sessionResetsAt: Date?
    private(set) var weeklyAllPercent: Double?
    private(set) var lastUpdated: Date?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let usage = try await Self.fetchUsage()
                apply(usage)
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func apply(_ usage: UsageResponse) {
        let model = usage.weeklyScoped(model: Self.modelName)
        modelPercent = model?.percent
        modelResetsAt = model?.resetsAt
        sessionPercent = usage.session?.percent
        sessionResetsAt = usage.session?.resetsAt
        weeklyAllPercent = usage.weeklyAll?.percent
        lastUpdated = Date()
    }

    // MARK: Networking

    enum UsageError: LocalizedError {
        case noCredentials
        case tokenExpired
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .noCredentials: "No Claude Code login found in Keychain"
            case .tokenExpired: "Token expired — run `claude` to refresh"
            case .http(let code): "Usage request failed (HTTP \(code))"
            }
        }
    }

    nonisolated static func fetchUsage() async throws -> UsageResponse {
        let credentials = try await Task.detached { try readCredentials() }.value
        if let expiresAt = credentials.expiresAt, expiresAt < Date() {
            throw UsageError.tokenExpired
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try JSONDecoder().decode(UsageResponse.self, from: data)
        case 401: throw UsageError.tokenExpired
        default: throw UsageError.http(status)
        }
    }

    struct Credentials {
        var accessToken: String
        var expiresAt: Date?
    }

    /// Uses `/usr/bin/security` because it is already on the Keychain item's ACL,
    /// so no access prompt appears.
    nonisolated static func readCredentials() throws -> Credentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UsageError.noCredentials }

        struct Stored: Decodable {
            struct OAuth: Decodable {
                var accessToken: String
                var expiresAt: Double?
            }
            var claudeAiOauth: OAuth?
        }
        guard let oauth = try? JSONDecoder().decode(Stored.self, from: data).claudeAiOauth else {
            throw UsageError.noCredentials
        }
        return Credentials(
            accessToken: oauth.accessToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) })
    }
}
