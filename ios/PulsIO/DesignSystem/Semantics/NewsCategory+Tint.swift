import SwiftUI

/// Category → colour is a *design* decision, so it lives here, not in Contracts.
/// Same mapping as the web app's `NEWS_COLORS`.
extension NewsCategory {
    var tint: Color {
        switch self {
        case .breaking, .crime: Palette.coral
        case .traffic: Palette.amber
        case .weather, .community: Palette.sky
        case .politics: Palette.purple
        case .economy, .sports: Palette.green
        case .tourism: Palette.teal
        case .general: Palette.muted
        }
    }

    /// Localised display name (key per case in the string catalog).
    var label: LocalizedStringResource {
        switch self {
        case .breaking: "news.category.breaking"
        case .crime: "news.category.crime"
        case .traffic: "news.category.traffic"
        case .weather: "news.category.weather"
        case .community: "news.category.community"
        case .politics: "news.category.politics"
        case .economy: "news.category.economy"
        case .sports: "news.category.sports"
        case .tourism: "news.category.tourism"
        case .general: "news.category.general"
        }
    }
}
