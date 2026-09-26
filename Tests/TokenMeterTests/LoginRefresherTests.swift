import Foundation
import Testing
@testable import TokenMeter

struct LoginRefresherTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func unknownExpiryIsNotDue() { #expect(!LoginRefresher.isDue(expiresAt: nil, now: now)) }
    @Test func farFutureIsNotDue() { #expect(!LoginRefresher.isDue(expiresAt: now.addingTimeInterval(3600), now: now)) }
    @Test func withinLeadTimeIsDue() { #expect(LoginRefresher.isDue(expiresAt: now.addingTimeInterval(600), now: now)) }
    @Test func alreadyExpiredIsDue() { #expect(LoginRefresher.isDue(expiresAt: now.addingTimeInterval(-60), now: now)) }
    @Test func keepLoginFreshDefaultsOff() { #expect(!UserDefaults.standard.bool(forKey: UsageService.keepLoginFreshKey)) }
}
