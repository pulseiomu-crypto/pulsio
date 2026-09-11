import Foundation
import Testing
@testable import PulsIO

struct ProfileDecodingTests {
    private func decode(_ json: String) throws -> Profile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: Data(json.utf8))
    }

    @Test func decodesFreshTriggerCreatedRowWithDefaults() throws {
        // Exactly what the on_auth_user_created trigger produces for a magic-link user (no name).
        let row = try decode("""
        {"id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","display_name":null,"user_type":"mauritian","district":null,
         "tier":"free","pulses_remaining":1,"pulses_total":1,"pulse_topup_balance":0,"morning_pulse_time":"07:00",
         "morning_pulse_enabled":false,"language":"en","priorities":[],"device_count":0,"referral_hotel":null,
         "created_at":"2026-09-11T04:00:00Z","updated_at":"2026-09-11T04:00:00Z"}
        """)
        #expect(row.displayName == nil)
        #expect(row.tier == .free)
        #expect(row.pulsesRemaining == 1)
        #expect(row.language == .en)
        #expect(row.priorities.isEmpty)
    }

    @Test func unknownTierAndNullsAreLenient() throws {
        let row = try decode("""
        {"id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","tier":"platinum","user_type":null,"language":"cr","priorities":null}
        """)
        #expect(row.tier == .free)
        #expect(row.userType == .mauritian)
        #expect(row.language == .cr)
        #expect(row.priorities.isEmpty)
    }
}
