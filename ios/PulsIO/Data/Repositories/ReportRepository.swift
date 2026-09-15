import CoreLocation
import Foundation
import Supabase

/// Community reports: read what's live, submit (photo → storage, row → RPC, model check → edge function),
/// and the three App Store UGC actions — flag, delete own, block the author.
protocol ReportRepository: Sendable {
    func visible(district: District?) async throws -> [Report]
    func submit(category: ReportCategory, description: String?, coordinate: CLLocationCoordinate2D, district: District?, photo: Data) async throws(ReportFailure) -> Report
    func confirm(_ id: Int64) async throws(ReportFailure) -> Report
    func flag(_ id: Int64, reason: String?) async throws(ReportFailure) -> Report
    func blockReporter(of id: Int64) async throws(ReportFailure)
    func deleteOwn(_ id: Int64) async throws(ReportFailure)
    func photoURL(for report: Report) -> URL?
}

struct SupabaseReportRepository: ReportRepository {
    let gateway: SupabaseGateway
    let baseURL: URL

    func visible(district: District?) async throws -> [Report] {
        try await gateway.client.rpc(Report.visibleRPC, params: ["p_district": district?.rawValue]).execute().value
    }

    func submit(category: ReportCategory, description: String?, coordinate: CLLocationCoordinate2D, district: District?, photo: Data) async throws(ReportFailure) -> Report {
        do {
            guard let uid = gateway.client.auth.currentSession?.user.id else { throw ReportFailure.code(.signIn) }
            // 1. The blurred JPEG goes into the submitter's own folder (storage policy enforces the folder).
            let path = "\(uid.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await gateway.client.storage.from(Report.photoBucket).upload(path, data: photo, options: FileOptions(contentType: "image/jpeg"))
            // 2. The row (pending). Nulls are sent explicitly: an omitted key changes the RPC's signature (404).
            let params: [String: AnyJSON] = [
                "p_category": .string(category.rawValue),
                "p_description": description.map(AnyJSON.string) ?? .null,
                "p_lat": .double(coordinate.latitude),
                "p_lng": .double(coordinate.longitude),
                "p_district": district.map { AnyJSON.string($0.rawValue) } ?? .null,
                "p_image_path": .string(path),
            ]
            let report: Report = try await gateway.client.rpc(Report.submitRPC, params: params).execute().value
            // 3. The model check (holds the report if the model or its key is unavailable). Outcome is read back.
            struct Invoke: Encodable { let report_id: Int64 }
            try? await gateway.client.functions.invoke(Report.moderationFunction, options: FunctionInvokeOptions(body: Invoke(report_id: report.id)))
            let refreshed: [Report] = try await gateway.client.from(Report.table).select().eq("id", value: Int(report.id)).limit(1).execute().value
            return refreshed.first ?? report
        } catch let failure as ReportFailure {
            throw failure
        } catch let error as PostgrestError {
            throw Self.map(error)
        } catch {
            throw .other(String(describing: error))
        }
    }

    func confirm(_ id: Int64) async throws(ReportFailure) -> Report {
        do { return try await gateway.client.rpc(Report.confirmRPC, params: ["p_report_id": id]).execute().value }
        catch let error as PostgrestError { throw Self.map(error) } catch { throw .other(String(describing: error)) }
    }

    func flag(_ id: Int64, reason: String?) async throws(ReportFailure) -> Report {
        let params: [String: AnyJSON] = ["p_report_id": .integer(Int(id)), "p_reason": reason.map(AnyJSON.string) ?? .null]
        do { return try await gateway.client.rpc(Report.flagRPC, params: params).execute().value }
        catch let error as PostgrestError { throw Self.map(error) } catch { throw .other(String(describing: error)) }
    }

    func blockReporter(of id: Int64) async throws(ReportFailure) {
        do { _ = try await gateway.client.rpc(Report.blockRPC, params: ["p_report_id": id]).execute() }
        catch let error as PostgrestError { throw Self.map(error) } catch { throw .other(String(describing: error)) }
    }

    func deleteOwn(_ id: Int64) async throws(ReportFailure) {
        do { _ = try await gateway.client.rpc(Report.deleteRPC, params: ["p_report_id": id]).execute() }
        catch let error as PostgrestError { throw Self.map(error) } catch { throw .other(String(describing: error)) }
    }

    func photoURL(for report: Report) -> URL? {
        guard let path = report.imagePath else { return nil }
        return baseURL.appendingPathComponent("storage/v1/object/public/\(Report.photoBucket)/\(path)")
    }

    private static func map(_ error: PostgrestError) -> ReportFailure {
        if let detail = error.detail, let code = ReportCode(rawValue: detail) { return .code(code) }
        return .other(error.message)
    }
}
