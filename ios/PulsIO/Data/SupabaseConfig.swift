import Foundation

/// Connection settings for the shared brain. Read from Info.plist, which is fed by `Config/*.xcconfig`,
/// so swapping projects (staging/prod) is a build-setting change, not a code change.
struct SupabaseConfig: Sendable {
    let url: URL
    let publishableKey: String

    enum Error: Swift.Error, LocalizedError {
        case missing(String)

        var errorDescription: String? {
            switch self {
            case .missing(let key): "Info.plist is missing \(key) — check ios/Config/Shared.xcconfig"
            }
        }
    }

    static func fromBundle(_ bundle: Bundle = .main) throws -> SupabaseConfig {
        guard let raw = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String, let url = URL(string: raw) else {
            throw Error.missing("SupabaseURL")
        }
        guard let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String, !key.isEmpty else {
            throw Error.missing("SupabasePublishableKey")
        }
        return SupabaseConfig(url: url, publishableKey: key)
    }
}
