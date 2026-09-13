import Foundation

/// Sunset for a date and coordinate, computed on the device (SPEC §14: no source needed). The standard
/// solar-position approximation (NOAA / Meeus), good to a minute or two — plenty for a panel row.
enum SunCalculator {
    /// Sunset (upper limb, standard refraction) on the local calendar day containing `date` in `timeZone`.
    static func sunset(on date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let localNoon = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: 12)) else { return nil }
        let jd = localNoon.timeIntervalSince1970 / 86400 + 2440587.5
        let n = (jd - 2451545.0 + 0.0008).rounded()
        let jStar = n - longitude / 360
        let m = (357.5291 + 0.98560028 * jStar).truncatingRemainder(dividingBy: 360)
        let mr = m * .pi / 180
        let c = 1.9148 * sin(mr) + 0.02 * sin(2 * mr) + 0.0003 * sin(3 * mr)
        let lambda = ((m + c + 180 + 102.9372).truncatingRemainder(dividingBy: 360)) * .pi / 180
        let jTransit = 2451545.0 + jStar + 0.0053 * sin(mr) - 0.0069 * sin(2 * lambda)
        let declination = asin(sin(lambda) * sin(23.44 * .pi / 180))
        let lat = latitude * .pi / 180
        let cosW = (sin(-0.83 * .pi / 180) - sin(lat) * sin(declination)) / (cos(lat) * cos(declination))
        guard cosW >= -1, cosW <= 1 else { return nil }   // polar day/night — not Mauritius
        let w = acos(cosW) * 180 / .pi
        let jSet = jTransit + w / 360
        return Date(timeIntervalSince1970: (jSet - 2440587.5) * 86400)
    }

    static let mauritius = TimeZone(identifier: "Indian/Mauritius")!
    static let islandCentre = (latitude: -20.2, longitude: 57.5)
}
