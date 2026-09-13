import Foundation
import Observation

/// App-level pulse state: today's quota as the server reports it, and the act of spending one.
/// The countdown is derived from `nextResetAt` (Mauritius midnight) so it needs no timer state.
@MainActor
@Observable
final class PulseStore {
    private(set) var status: PulseStatus?
    private(set) var isFiring = false
    private(set) var lastFailure: PulseFailure?

    private let pulses: any PulseRepository
    private let session: SessionStore
    private let districts: DistrictStore

    init(pulses: any PulseRepository, session: SessionStore, districts: DistrictStore) {
        self.pulses = pulses
        self.session = session
        self.districts = districts
    }

    /// Signed-out users see the gate, not a count.
    var isSpent: Bool { status.map { !$0.canPulse } ?? false }

    func refresh() async {
        guard session.isSignedIn else { status = nil; return }
        do { status = try await pulses.status() } catch { lastFailure = .other(String(describing: error)) }
    }

    /// Spend one. On success the returned status is the post-spend state; the caller runs the ceremony.
    func fire() async -> Result<PulseStatus, PulseFailure> {
        guard session.isSignedIn else { return .failure(.code(.signIn)) }
        isFiring = true
        defer { isFiring = false }
        do {
            let result = try await pulses.consume(district: districts.district)
            status = result
            lastFailure = nil
            return .success(result)
        } catch {
            lastFailure = error
            if case .code(.spent) = error { await refresh() }
            return .failure(error)
        }
    }

    /// "hh:mm" (or "mm:ss" under an hour) until the next quota, for the spent state.
    func countdown(now: Date = .now) -> String? {
        guard let reset = status?.nextResetAt else { return nil }
        let seconds = max(0, Int(reset.timeIntervalSince(now).rounded()))
        let h = seconds / 3600, m = (seconds / 60) % 60, s = seconds % 60
        return h > 0 ? String(format: "%02d:%02d", h, m) : String(format: "%02d:%02d", m, s)
    }
}
