/// Mirrors `priority` in `contracts/enums.json` — the onboarding priorities (FRONTEND §A step 3), stored in
/// `pulsio_profiles.priorities`. `pulse_snapshot()` reorders the panel by them (traffic/news have no rows yet).
enum Priority: String, Codable, CaseIterable, Sendable, Identifiable {
    case ceb, weather, traffic, news, cyclone, fuel

    var id: String { rawValue }
    static let maxSelected = 3
}
