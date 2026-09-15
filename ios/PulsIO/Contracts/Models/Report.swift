import CoreLocation
import Foundation

/// One row of `pulsio_reports` (hand-written against the schema, ARCHITECTURE §3).
struct Report: Codable, Identifiable, Hashable, Sendable {
    static let table = "pulsio_reports"
    static let visibleRPC = "visible_reports"
    static let submitRPC = "submit_report"
    static let confirmRPC = "confirm_report"
    static let flagRPC = "flag_report"
    static let blockRPC = "block_reporter"
    static let deleteRPC = "delete_own_report"
    static let moderationFunction = "moderate-report"
    static let photoBucket = "report-photos"

    let id: Int64
    let userID: UUID?
    let category: ReportCategory
    let description: String?
    let lat: Double
    let lng: Double
    let district: District?
    let status: ReportStatus
    let confirmations: Int
    let confirmedBy: [UUID]
    let flagCount: Int
    let imagePath: String?
    let imageURL: String?
    let modelVerdict: String?
    let createdAt: Date?
    let expiresAt: Date?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }

    enum CodingKeys: String, CodingKey {
        case id, category, description, lat, lng, district, status, confirmations
        case userID = "user_id"
        case confirmedBy = "confirmed_by"
        case flagCount = "flag_count"
        case imagePath = "image_path"
        case imageURL = "image_url"
        case modelVerdict = "model_verdict"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        userID = try c.decodeIfPresent(UUID.self, forKey: .userID)
        category = try c.decodeIfPresent(ReportCategory.self, forKey: .category) ?? .other
        description = try c.decodeIfPresent(String.self, forKey: .description)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        district = try District.decodeLenient(from: c, forKey: .district)
        status = try c.decodeIfPresent(ReportStatus.self, forKey: .status) ?? .pending
        confirmations = try c.decodeIfPresent(Int.self, forKey: .confirmations) ?? 0
        confirmedBy = try c.decodeIfPresent([UUID].self, forKey: .confirmedBy) ?? []
        flagCount = try c.decodeIfPresent(Int.self, forKey: .flagCount) ?? 0
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        modelVerdict = try c.decodeIfPresent(String.self, forKey: .modelVerdict)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
    }

    /// The 2 km rule, on the device (SPEC §11): the confirmer's coordinate never leaves the phone.
    func isWithinConfirmRadius(of location: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: lat, longitude: lng).distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude)) <= ReportRules.confirmRadiusMetres
    }
}

/// U-codes the report rules can raise (contracts/errors.json).
enum ReportCode: String, Sendable {
    case signIn = "P-100", blocked = "U-201", photoRequired = "U-202", pinOutside = "U-203"
    case notLive = "U-210", own = "U-211", alreadyConfirmed = "U-212", tooFar = "U-213"

    var messageKey: LocalizedStringResource {
        switch self {
        case .signIn: "pulse.error.signIn"
        case .blocked: "report.error.blocked"
        case .photoRequired: "report.error.photoRequired"
        case .pinOutside: "report.error.pinOutside"
        case .notLive: "report.error.notLive"
        case .own: "report.error.own"
        case .alreadyConfirmed: "report.error.alreadyConfirmed"
        case .tooFar: "report.error.tooFar"
        }
    }
}

enum ReportFailure: Error, Equatable {
    case code(ReportCode)
    case other(String)
}
