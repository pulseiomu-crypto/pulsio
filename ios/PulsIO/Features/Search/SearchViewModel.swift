import CoreLocation
import Foundation
import Observation

/// Search state: the query, an optional category, results with on-device distances. The server sees nothing —
/// the whole thing runs against the local POI store (SPEC §10/§20).
@MainActor
@Observable
final class SearchViewModel {
    struct Hit: Identifiable, Hashable {
        let poi: POIRecord
        let metres: CLLocationDistance?
        var id: Int64 { poi.id }
    }

    enum Ordering: Equatable { case distance, alphabetical }

    var query = "" { didSet { schedule() } }
    private(set) var category: POIType?
    private(set) var hits: [Hit] = []
    private(set) var ordering: Ordering = .alphabetical
    private(set) var isSearching = false

    /// Categories offered as chips: search-only first (that's what search is for), then the rest.
    static let categories: [POIType] = [.pharmacy, .supermarket, .police, .clinic, .mall, .town, .shelter, .hospital, .fuel, .beach, .landmark, .waterfall, .hike, .park, .airport, .ferry, .marina]

    private let store: POIStore
    private let districts: DistrictStore
    private var task: Task<Void, Never>?
    /// Matches type labels in the current locale ("pharmacie") as well as raw type names.
    private let typeMatcher: (String) -> Set<POIType>

    init(store: POIStore, districts: DistrictStore, typeMatcher: @escaping (String) -> Set<POIType>) {
        self.store = store
        self.districts = districts
        self.typeMatcher = typeMatcher
    }

    func select(_ category: POIType?) {
        self.category = (category == self.category) ? nil : category
        schedule()
    }

    private func schedule() {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.run()
        }
    }

    func run() async {
        isSearching = true
        defer { isSearching = false }
        let reference = await districts.referenceCoordinate()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // "pharmacy"/"pharmacie" typed as a word acts like the category chip.
        let typed = typeMatcher(q)
        var types: Set<POIType>? = category.map { [$0] }
        var text = q
        if types == nil, !typed.isEmpty { types = typed; text = "" }
        guard !(text.isEmpty && types == nil) else { hits = []; return }
        do {
            let rows = try await store.search(text, types: types)
            if let reference {
                let from = CLLocation(latitude: reference.latitude, longitude: reference.longitude)
                hits = rows.map { Hit(poi: $0, metres: CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: from)) }
                    .sorted { ($0.metres ?? .infinity) < ($1.metres ?? .infinity) }
                ordering = .distance
            } else {
                hits = rows.map { Hit(poi: $0, metres: nil) }.sorted { $0.poi.name.localizedCaseInsensitiveCompare($1.poi.name) == .orderedAscending }
                ordering = .alphabetical
            }
        } catch {
            hits = []
        }
    }
}
