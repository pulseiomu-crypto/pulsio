import Foundation

/// Things a user can *do* that need an account (FRONTEND §4: browse freely, sign in to act).
/// Browsing — map, POIs, news, PulsScore, emergency dial — is never an `Act`, so it never reaches the gate.
enum Act: Hashable, Sendable {
    case firePulse
    case submitReport
    case confirmReport
    case saveToProfile
    case subscribe
    /// Gated normally; opened to everyone while an emergency is active.
    case viewCycloneAlerts
    case viewShelters
}

enum AccessDecision: Equatable, Sendable {
    case allowed
    case requiresSignIn
}

/// Pure rule: given who's signed in and whether an emergency is active, may this act proceed?
/// Kept free of SwiftUI so it's unit-testable and identical in shape to the web implementation.
struct AccessPolicy: Sendable {
    func decide(_ act: Act, isSignedIn: Bool, emergency: EmergencyState) -> AccessDecision {
        if isSignedIn { return .allowed }
        switch act {
        case .viewCycloneAlerts, .viewShelters:
            return emergency.isActive ? .allowed : .requiresSignIn
        case .firePulse, .submitReport, .confirmReport, .saveToProfile, .subscribe:
            return .requiresSignIn
        }
    }
}
