import Foundation
import Observation
import OSLog

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
    /// Longest pause after a 429, whatever Retry-After says.
    static let maxBackoff: TimeInterval = 30 * 60
    nonisolated static let log = Logger(subsystem: "com.dialogs.TokenMeter", category: "usage")

    private(set) var modelPercent: Double?
    private(set) var modelResetsAt: Date?
    private(set) var sessionPercent: Double?
    private(set) var sessionResetsAt: Date?
    private(set) var weeklyAllPercent: Double?
    private(set) var lastUpdated: Date?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private var timer: Timer?
    /// Set from a 429's Retry-After; timer polls are skipped until then.
    private var backoffUntil: Date?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let backoffUntil = self.backoffUntil, backoffUntil > Date() { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                apply(try await Self.fetchUsage())
                errorMessage = nil
                backoffUntil = nil
            } catch UsageError.tokenExpired {
                errorMessage = Self.staleMessage(since: lastUpdated)
            } catch UsageError.rateLimited(let until) {
                let limit = Date().addingTimeInterval(Self.maxBackoff)
                backoffUntil = min(until ?? Date().addingTimeInterval(Self.pollInterval), limit)
                errorMessage = UsageError.rateLimited(until: backoffUntil).errorDescription
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Message shown when Claude Code's login has expired.
    nonisolated static func staleMessage(since lastUpdated: Date?, now: Date = Date(),
                                         calendar: Calendar = .current) -> String {
        let action = "open any `claude` session to refresh"
        guard let lastUpdated else { return "Claude Code login expired — \(action)" }
        let time = calendar.isDate(lastUpdated, inSameDayAs: now)
            ? lastUpdated.formatted(date: .omitted, time: .shortened)
            : lastUpdated.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return "Stale since \(time) — \(action)"
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
        case rateLimited(until: Date?)
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .noCredentials: "No Claude Code login found in Keychain"
            case .tokenExpired: UsageService.staleMessage(since: nil)
            case .rateLimited(let until?):
                "Rate limited — retrying at \(until.formatted(date: .omitted, time: .shortened))"
            case .rateLimited(nil): "Rate limited — retrying later"
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
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if status != 200 { logFailure(status: status, response: http, data: data) }
        switch status {
        case 200: return try JSONDecoder().decode(UsageResponse.self, from: data)
        case 401: throw UsageError.tokenExpired
        case 429: throw UsageError.rateLimited(until: retryAfter(http?.value(forHTTPHeaderField: "Retry-After")))
        default: throw UsageError.http(status)
        }
    }

    /// Records a failed request in the unified log and ~/Library/Logs/TokenMeter.log.
    /// Never logs the token; only the status, rate-limit headers and the start of the body.
    nonisolated private static func logFailure(status: Int, response: HTTPURLResponse?, data: Data) {
        let headers = (response?.allHeaderFields ?? [:])
            .compactMap { key, value -> String? in
                let name = "\(key)".lowercased()
                guard name == "retry-after" || name.contains("ratelimit") || name == "request-id" else { return nil }
                return "\(name)=\(value)"
            }
            .sorted().joined(separator: " ")
        let body = String(decoding: data.prefix(300), as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
        let line = "HTTP \(status) \(headers) body=\(body)"
        log.error("\(line, privacy: .public)")

        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/TokenMeter.log")
        let entry = Data("\(Date().formatted(.iso8601)) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: entry)
        } else {
            try? entry.write(to: url)
        }
    }

    /// Parses a Retry-After header given in seconds or as an HTTP date.
    nonisolated static func retryAfter(_ value: String?, now: Date = Date()) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value) { return now.addingTimeInterval(seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
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
