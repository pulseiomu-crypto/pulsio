import CoreLocation
import Foundation
import Observation

/// Live community reports for the map and the actions on them. Reads through `visible_reports()` — the
/// server decides what I may see (live, or my own pending; never a blocked author).
@MainActor
@Observable
final class ReportStore {
    private(set) var reports: [Report] = []
    private(set) var isSubmitting = false
    private(set) var lastFailure: ReportFailure?

    private let repository: any ReportRepository
    private let session: SessionStore
    private let districts: DistrictStore

    init(repository: any ReportRepository, session: SessionStore, districts: DistrictStore) {
        self.repository = repository
        self.session = session
        self.districts = districts
    }

    func refresh() async {
        do { reports = try await repository.visible(district: nil) } catch { lastFailure = .other(String(describing: error)) }
    }

    func report(id: Int64) -> Report? { reports.first { $0.id == id } }
    func isMine(_ report: Report) -> Bool { report.userID != nil && report.userID == session.user?.id }
    func photoURL(for report: Report) -> URL? { repository.photoURL(for: report) }

    /// Submit: the photo has already been through `PhotoPipeline`. Returns the report as it stands after
    /// the model check (pending = held for review, unconfirmed = live).
    func submit(category: ReportCategory, description: String?, coordinate: CLLocationCoordinate2D, photo: Data) async -> Result<Report, ReportFailure> {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let report = try await repository.submit(category: category, description: description, coordinate: coordinate, district: districts.district, photo: photo)
            await refresh()
            return .success(report)
        } catch {
            lastFailure = error
            return .failure(error)
        }
    }

    func confirm(_ report: Report) async -> ReportFailure? {
        do { _ = try await repository.confirm(report.id); await refresh(); return nil } catch { return error }
    }

    func flag(_ report: Report, reason: String?) async -> ReportFailure? {
        do { _ = try await repository.flag(report.id, reason: reason); await refresh(); return nil } catch { return error }
    }

    func blockReporter(of report: Report) async -> ReportFailure? {
        do { try await repository.blockReporter(of: report.id); await refresh(); return nil } catch { return error }
    }

    func deleteOwn(_ report: Report) async -> ReportFailure? {
        do { try await repository.deleteOwn(report.id); await refresh(); return nil } catch { return error }
    }
}
