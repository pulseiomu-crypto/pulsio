import SwiftUI

/// "You browse a beach; you search for a pharmacy." Name or category, sorted by distance computed here on
/// the device, each hit tapping through to the map. Approximate shelters are findable, clearly labelled, with
/// their numbers tappable — and never presented as pinned.
struct SearchScreen: View {
    @Environment(\.poiStore) private var store
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    @State private var model: SearchViewModel?
    @FocusState private var focused: Bool
    let onOpen: (POIRecord) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    @Bindable var model = model
                    VStack(spacing: 0) {
                        HStack(spacing: Metrics.Space.sm) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                            TextField(text: $model.query, prompt: Text("search.placeholder").foregroundColor(Palette.muted2)) { Text("search.title") }
                                .focused($focused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .font(Typography.body(15)).foregroundStyle(Palette.ink)
                                .accessibilityIdentifier("search.field")
                            if !model.query.isEmpty {
                                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted2) }
                                    .buttonStyle(.plain).frame(width: 32, height: 44)
                            }
                        }
                        .padding(.horizontal, Metrics.Space.md)
                        .frame(minHeight: 48)
                        .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                        .padding(.horizontal, Metrics.Space.lg)
                        .padding(.top, Metrics.Space.sm)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Metrics.Space.sm) {
                                ForEach(SearchViewModel.categories, id: \.self) { type in
                                    SelectableChip(title: type.label, symbol: type.searchSymbol, isOn: model.category == type) { model.select(type) }
                                        .accessibilityIdentifier("search.category.\(type.rawValue)")
                                }
                            }
                            .padding(.horizontal, Metrics.Space.lg)
                            .padding(.vertical, Metrics.Space.md)
                        }

                        orderingLine(model)

                        List {
                            ForEach(model.hits) { hit in
                                SearchRow(hit: hit) { onOpen(hit.poi); dismiss() }
                                    .listRowBackground(Palette.abyss)
                                    .listRowSeparatorTint(Palette.hair)
                                    .listRowInsets(EdgeInsets(top: Metrics.Space.md, leading: Metrics.Space.lg, bottom: Metrics.Space.md, trailing: Metrics.Space.lg))
                            }
                            if model.hits.isEmpty {
                                Text(model.query.isEmpty && model.category == nil ? "search.hint" : "search.empty")
                                    .font(Typography.mono(11)).foregroundStyle(Palette.muted)
                                    .frame(maxWidth: .infinity).padding(Metrics.Space.xl)
                                    .listRowBackground(Color.clear)
                                    .accessibilityIdentifier("search.status")
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.immediately)
                    }
                } else {
                    Color.clear
                }
            }
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("common.cancel") } } }
        }
        .task {
            if model == nil {
                model = SearchViewModel(store: store, districts: districts) { text in
                    let needle = text.lowercased()
                    guard needle.count >= 3 else { return [] }
                    return Set(POIType.allCases.filter { type in
                        type.rawValue.hasPrefix(needle) || String(localized: type.label).lowercased().hasPrefix(needle)
                    })
                }
                focused = true
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func orderingLine(_ model: SearchViewModel) -> some View {
        if !model.hits.isEmpty {
            HStack(spacing: Metrics.Space.sm) {
                Image(systemName: model.ordering == .distance ? "location.fill" : "textformat.abc").font(.system(size: 10, weight: .semibold))
                Text(model.ordering == .distance ? "search.ordering.distance" : "search.ordering.alphabetical")
            }
            .font(Typography.mono(9)).tracking(0.12).textCase(.uppercase)
            .foregroundStyle(model.ordering == .distance ? Palette.muted : Palette.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.Space.lg)
            .padding(.bottom, Metrics.Space.xs)
            .accessibilityIdentifier("search.ordering")
        }
    }
}

private struct SearchRow: View {
    let hit: SearchViewModel.Hit
    let open: () -> Void

    private var poi: POIRecord { hit.poi }
    private var isApproximateShelter: Bool { poi.type == .shelter && poi.locationPrecision == .approximate }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Space.sm) {
            Button(action: open) {
                HStack(alignment: .top, spacing: Metrics.Space.md) {
                    Image(systemName: poi.type.searchSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isApproximateShelter ? Palette.muted : poi.type.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(poi.name).font(Typography.body(14, weight: .medium)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 0) {
                            Text(poi.type.label).foregroundStyle(poi.type.tint)
                            if let village = isApproximateShelter ? POIContacts.village(for: poi) : poi.district {
                                Text(verbatim: " · ").foregroundStyle(Palette.muted2)
                                Text(village).foregroundStyle(Palette.muted)
                            }
                        }
                        .font(Typography.mono(10)).lineLimit(1)
                        if isApproximateShelter {
                            Text("search.shelter.approximate")
                                .font(Typography.mono(10)).foregroundStyle(Palette.amber)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("search.approximate")
                        }
                    }
                    Spacer(minLength: Metrics.Space.sm)
                    if let metres = hit.metres {
                        Text(Self.distance(metres))
                            .font(Typography.mono(11, weight: .semibold)).foregroundStyle(Palette.ink).monospacedDigit()
                            .accessibilityIdentifier("search.distance")
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.result.\(poi.id)")

            let contacts = POIContacts.parse(poi.phone)
            if !contacts.isEmpty {
                FlowChips {
                    ForEach(contacts) { c in
                        if let url = c.url {
                            Link(destination: url) {
                                HStack(spacing: 5) {
                                    Image(systemName: c.role == .supervisor ? "person.fill" : "phone.fill").font(.system(size: 10, weight: .semibold))
                                    Text(c.display)
                                }
                                .font(Typography.mono(11, weight: .semibold)).foregroundStyle(Palette.teal)
                                .padding(.horizontal, Metrics.Space.md).frame(minHeight: 36)
                                .background(Palette.teal.opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(Palette.hairActive, lineWidth: Metrics.hairline))
                            }
                            .accessibilityLabel(Text(c.role == .supervisor ? "search.phone.supervisor" : "search.phone.centre"))
                            .accessibilityIdentifier("search.phone.\(c.number)")
                        }
                    }
                }
                .padding(.leading, 22 + Metrics.Space.md)
            }
        }
    }

    static func distance(_ metres: Double) -> String {
        metres < 950 ? "\(Int((metres / 50).rounded() * 50)) m" : String(format: "%.1f km", metres / 1000)
    }
}

extension POIType {
    var searchSymbol: String {
        switch self {
        case .pharmacy: "cross.case.fill"
        case .supermarket: "cart.fill"
        case .mall: "bag.fill"
        case .police: "shield.lefthalf.filled"
        case .clinic: "stethoscope"
        case .town: "building.2.fill"
        case .shelter: "house.lodge.fill"
        case .hospital: "cross.fill"
        case .fuel: "fuelpump.fill"
        case .beach: "beach.umbrella.fill"
        case .landmark: "star.fill"
        case .waterfall: "drop.fill"
        case .hike: "figure.hiking"
        case .park: "tree.fill"
        case .viewpoint: "binoculars.fill"
        case .airport: "airplane"
        case .ferry: "ferry.fill"
        case .marina: "sailboat.fill"
        case .helipad: "helicopter"
        case .restaurant: "fork.knife"
        case .hotel: "bed.double.fill"
        case .market: "basket.fill"
        case .other: "mappin"
        }
    }
}
