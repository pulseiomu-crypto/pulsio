import Foundation
import Supabase

/// The signed-in user's own `pulsio_profiles` row. RLS restricts every query here to `auth.uid() = id`.
protocol ProfileRepository: Sendable {
    /// The profile, creating it if the sign-up trigger somehow didn't (belt and braces; the trigger is the rule).
    func ensureProfile(for userID: UUID) async throws -> Profile
    func updateDisplayName(_ name: String?, for userID: UUID) async throws -> Profile
}

struct SupabaseProfileRepository: ProfileRepository {
    let gateway: SupabaseGateway

    func ensureProfile(for userID: UUID) async throws -> Profile {
        let existing: [Profile] = try await gateway.client
            .from(Profile.table).select().eq("id", value: userID).limit(1).execute().value
        if let profile = existing.first { return profile }

        let created: [Profile] = try await gateway.client
            .from(Profile.table).insert(["id": userID.uuidString]).select().execute().value
        guard let profile = created.first else { throw ProfileError.notCreated }
        return profile
    }

    func updateDisplayName(_ name: String?, for userID: UUID) async throws -> Profile {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated: [Profile] = try await gateway.client
            .from(Profile.table)
            .update(["display_name": trimmed.flatMap { $0.isEmpty ? nil : $0 }, "updated_at": ISO8601DateFormatter().string(from: .now)])
            .eq("id", value: userID)
            .select()
            .execute().value
        guard let profile = updated.first else { throw ProfileError.notFound }
        return profile
    }

    enum ProfileError: Error { case notCreated, notFound }
}
