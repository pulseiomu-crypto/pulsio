import SwiftUI

private struct POIStoreKey: EnvironmentKey {
    // Loud default: a feature rendered outside the composition root gets an empty in-memory store, never a crash.
    static let defaultValue: POIStore = (try? POIStore.inMemory()) ?? { fatalError("in-memory POI store unavailable") }()
}

extension EnvironmentValues {
    var poiStore: POIStore {
        get { self[POIStoreKey.self] }
        set { self[POIStoreKey.self] = newValue }
    }
}
