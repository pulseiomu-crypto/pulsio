import Foundation

/// The single row of the `pulsio_emergency_state` view — Supabase's answer to "is an emergency active?"
/// (cyclone warning/active bulletin in the last 24h, or a NerveCentre-declared emergency). Public-read.
struct EmergencyState: Codable, Equatable, Sendable {
    static let view = "pulsio_emergency_state"

    let cycloneActive: Bool
    let emergencyDeclared: Bool
    let emergencyMessage: String?
    let evaluatedAt: Date?

    /// Either condition opens the emergency exception (cyclone alerts + shelters for signed-out users).
    var isActive: Bool { cycloneActive || emergencyDeclared }

    static let none = EmergencyState(cycloneActive: false, emergencyDeclared: false, emergencyMessage: nil, evaluatedAt: nil)

    enum CodingKeys: String, CodingKey {
        case cycloneActive = "cyclone_active"
        case emergencyDeclared = "emergency_declared"
        case emergencyMessage = "emergency_message"
        case evaluatedAt = "evaluated_at"
    }

    init(cycloneActive: Bool, emergencyDeclared: Bool, emergencyMessage: String?, evaluatedAt: Date?) {
        self.cycloneActive = cycloneActive
        self.emergencyDeclared = emergencyDeclared
        self.emergencyMessage = emergencyMessage
        self.evaluatedAt = evaluatedAt
    }
}
