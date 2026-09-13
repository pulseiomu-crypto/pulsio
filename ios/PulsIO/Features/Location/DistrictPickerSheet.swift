import SwiftUI

/// Pick a district by hand. Presented after a declined permission (with SPEC §10's verbatim framing —
/// never "features will be unavailable") and from settings/the map chip at any time.
struct DistrictPickerSheet: View {
    enum Framing {
        case afterDecline
        case general
    }

    let framing: Framing
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(framing == .afterDecline ? "district.framing.declined" : "district.framing.general")
                        .font(Typography.body(14))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("district.framing")
                    if districts.locationAvailability == .denied {
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Label { Text("district.enableInSettings") } icon: { Image(systemName: "location.slash") }
                                .font(Typography.mono(11, weight: .semibold))
                                .foregroundStyle(Palette.teal)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section {
                    ForEach(District.allCases) { district in
                        Button {
                            Task { await districts.setManual(district); dismiss() }
                        } label: {
                            HStack {
                                Text(district.label).foregroundStyle(Palette.ink)
                                Spacer()
                                if districts.district == district {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.teal)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("district.option.\(district.rawValue)")
                    }
                    .listRowBackground(Palette.deep)
                } header: {
                    Eyebrow(text: "district.pick.eyebrow")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("district.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("district.cancel")
                }
            }
        }
        .presentationDetents([.large])
    }
}
