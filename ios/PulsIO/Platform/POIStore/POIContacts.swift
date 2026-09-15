import Foundation

/// Phone numbers as the shelter list ships them — one string, several numbers with roles:
/// `"Centre 4520237 · Supervisor 4522641 59029210"`. During a cyclone a working number for the nearest
/// centre may matter more than a pin, so each becomes its own tappable `tel:` link with its role kept.
struct PhoneContact: Hashable, Sendable, Identifiable {
    enum Role: String, Sendable { case centre, supervisor, general }
    let role: Role
    let number: String
    var id: String { "\(role.rawValue):\(number)" }
    var url: URL? { URL(string: "tel:\(number)") }
    /// Mauritian numbers are 7 (landline) or 8 (mobile) digits; shown as `454 2641` / `5902 9210`.
    var display: String {
        switch number.count {
        case 7: return String(number.prefix(3)) + " " + String(number.suffix(4))
        case 8: return String(number.prefix(4)) + " " + String(number.suffix(4))
        default: return number
        }
    }
}

enum POIContacts {
    /// Every 7–8 digit run becomes a contact; the role is whichever label preceded it last.
    static func parse(_ raw: String?) -> [PhoneContact] {
        guard let raw, !raw.isEmpty else { return [] }
        var contacts: [PhoneContact] = []
        var role: PhoneContact.Role = .general
        var digits = ""
        var word = ""
        func flushDigits() {
            if (7...8).contains(digits.count), !contacts.contains(where: { $0.number == digits }) {
                contacts.append(PhoneContact(role: role, number: digits))
            }
            digits = ""
        }
        func flushWord() {
            switch word.lowercased() {
            case "centre", "center", "hall", "office": role = .centre
            case "supervisor", "superviseur", "responsable": role = .supervisor
            default: break
            }
            word = ""
        }
        for ch in raw {
            if ch.isNumber { flushWord(); digits.append(ch) }
            else if ch.isLetter { flushDigits(); word.append(ch) }
            else { flushDigits(); flushWord() }
        }
        flushDigits(); flushWord()
        return contacts
    }

    /// The village an approximate shelter's pin stands for ("pin is Bambous centre" in the description),
    /// else the last comma-separated part of the name ("…, Anse Jonchée").
    static func village(for poi: POIRecord) -> String? {
        if let description = poi.description, let range = description.range(of: #"pin is (.+?) centre"#, options: .regularExpression) {
            let match = String(description[range])
            return match.replacingOccurrences(of: "pin is ", with: "").replacingOccurrences(of: " centre", with: "")
        }
        let parts = poi.name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.count > 1 ? parts.last : nil
    }
}
