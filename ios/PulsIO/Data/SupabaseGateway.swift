import Foundation
import Supabase

/// The single Supabase client for the app. Repositories hold a gateway; nothing outside `Data/` does.
///
/// ARCHITECTURE §4: views never touch the network; a ViewModel calls a repository; the repository calls
/// through here. Auth/session will attach to this same client later — one connection, one place.
final class SupabaseGateway: Sendable {
    let client: SupabaseClient

    init(config: SupabaseConfig) {
        client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.publishableKey)
    }
}
