import Foundation
import Testing
@testable import PulsIO

/// Browse freely, sign in to act — with the emergency exception (FRONTEND §4, SPEC §11/§15).
struct AccessPolicyTests {
    private let policy = AccessPolicy()
    private let calm = EmergencyState.none
    private let cyclone = EmergencyState(cycloneActive: true, emergencyDeclared: false, emergencyMessage: nil, evaluatedAt: nil)
    private let declared = EmergencyState(cycloneActive: false, emergencyDeclared: true, emergencyMessage: "Flooding", evaluatedAt: nil)

    @Test(arguments: [Act.firePulse, .submitReport, .confirmReport, .saveToProfile, .subscribe, .viewCycloneAlerts, .viewShelters])
    func signedInUsersMayDoEverything(act: Act) {
        #expect(policy.decide(act, isSignedIn: true, emergency: calm) == .allowed)
    }

    @Test(arguments: [Act.firePulse, .submitReport, .confirmReport, .saveToProfile, .subscribe])
    func actsRequireSignInWhenSignedOut(act: Act) {
        #expect(policy.decide(act, isSignedIn: false, emergency: calm) == .requiresSignIn)
        // An emergency never unlocks acts that write or pay.
        #expect(policy.decide(act, isSignedIn: false, emergency: cyclone) == .requiresSignIn)
    }

    @Test(arguments: [Act.viewCycloneAlerts, .viewShelters])
    func emergencyOpensSafetySurfacesToSignedOut(act: Act) {
        #expect(policy.decide(act, isSignedIn: false, emergency: calm) == .requiresSignIn)
        #expect(policy.decide(act, isSignedIn: false, emergency: cyclone) == .allowed)
        #expect(policy.decide(act, isSignedIn: false, emergency: declared) == .allowed)
    }
}
