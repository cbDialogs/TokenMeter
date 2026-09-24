import Foundation

/// Subset of `GET /api/oauth/usage`. Everything is optional because the
/// endpoint is undocumented and its shape may change.
struct UsageResponse: Decodable, Sendable {
    var limits: [Limit]?

    struct Limit: Decodable, Sendable {
        var kind: String?
        var percent: Double?
        var resetsAt: Date?
        var scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try? c.decodeIfPresent(String.self, forKey: .kind)
            percent = try? c.decodeIfPresent(Double.self, forKey: .percent)
            scope = try? c.decodeIfPresent(Scope.self, forKey: .scope)
            if let s = try? c.decodeIfPresent(String.self, forKey: .resetsAt) {
                resetsAt = UsageResponse.parseDate(s)
            }
        }
    }

    struct Scope: Decodable, Sendable {
        var model: Model?
        struct Model: Decodable, Sendable {
            var displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limits = try? c.decodeIfPresent([Limit].self, forKey: .limits)
    }

    enum CodingKeys: String, CodingKey { case limits }

    // MARK: Lookups

    var session: Limit? { limits?.first { $0.kind == "session" } }
    var weeklyAll: Limit? { limits?.first { $0.kind == "weekly_all" } }

    func weeklyScoped(model name: String) -> Limit? {
        limits?.first {
            $0.kind == "weekly_scoped"
                && $0.scope?.model?.displayName?.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Parses ISO-8601 timestamps with or without (microsecond) fractional seconds.
    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // Drop fractional seconds; ISO8601DateFormatter can't handle 6 digits.
        let trimmed = string.replacingOccurrences(
            of: #"\.\d+"#, with: "", options: .regularExpression)
        return formatter.date(from: trimmed)
    }
}
