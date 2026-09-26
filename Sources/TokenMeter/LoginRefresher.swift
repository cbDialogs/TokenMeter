import Foundation
import OSLog

/// Renews Claude Code's login by running a tiny `claude -p` prompt.
///
/// TokenMeter never talks to the OAuth refresh endpoint itself (see
/// `UsageService`). Instead, when the user opts in, it lets Claude Code do
/// the refresh the normal way: any `claude` run with an expired access token
/// rotates the token and writes the new one to the Keychain.
enum LoginRefresher {
    /// Refresh this long before the access token expires.
    static let leadTime: TimeInterval = 15 * 60
    /// Give up on a hung `claude` after this long.
    static let timeout: TimeInterval = 90

    /// Smallest prompt we can make: Haiku, no tools, no saved session.
    /// (`--bare` is deliberately absent: it skips the Keychain login.)
    static let arguments = [
        "-p", "--no-session-persistence", "--tools", "", "--model", "haiku",
        "Reply with the single word OK.",
    ]

    enum Failure: LocalizedError {
        case claudeNotFound
        case timedOut
        case exited(Int32, String)
        case notRenewed

        var errorDescription: String? {
            switch self {
            case .claudeNotFound: "`claude` not found"
            case .timedOut: "`claude` timed out"
            case .exited(let code, let output):
                output.isEmpty ? "`claude` exited with \(code)" : "`claude` said: \(output)"
            case .notRenewed: "`claude` ran but the login was not renewed"
            }
        }
    }

    /// True when the token has expired or will within `leadTime`.
    /// An unknown expiry is left alone; a 401 will still trigger a refresh.
    static func isDue(expiresAt: Date?, now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) < leadTime
    }

    /// Runs `claude -p` off the main thread. Throws `Failure` on any problem;
    /// the caller decides whether the Keychain now holds a fresh token.
    static func run() async throws {
        try await Task.detached(priority: .utility) { try runBlocking() }.value
    }

    private static func runBlocking() throws {
        guard let claude = locateClaude() else { throw Failure.claudeNotFound }
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("TokenMeter-keepalive")
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claude)
        process.arguments = arguments
        process.currentDirectoryURL = workDir
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchPath.joined(separator: ":")
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice

        UsageService.log.info("Running \(claude, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")
        try process.run()
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let timedOut = watchdog.isCancelled == false && process.terminationReason == .uncaughtSignal
        watchdog.cancel()

        if timedOut { throw Failure.timedOut }
        guard process.terminationStatus == 0 else {
            let text = String(decoding: data.suffix(200), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            throw Failure.exited(process.terminationStatus, text)
        }
    }

    // MARK: Finding claude

    /// Directories searched for `claude`, and the PATH given to it.
    private static var searchPath: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin", "\(home)/.claude/local", "\(home)/.npm-global/bin",
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
    }

    /// Looks in the usual install locations, then asks the login shell.
    static func locateClaude() -> String? {
        let fm = FileManager.default
        for dir in searchPath {
            let path = "\(dir)/claude"
            if fm.isExecutableFile(atPath: path) { return path }
        }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lc", "command -v claude"]
        let pipe = Pipe()
        shell.standardOutput = pipe
        shell.standardError = FileHandle.nullDevice
        shell.standardInput = FileHandle.nullDevice
        guard (try? shell.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        shell.waitUntilExit()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return shell.terminationStatus == 0 && fm.isExecutableFile(atPath: path) ? path : nil
    }
}
