import SwiftUI

/// The map screen: full-bleed map, layer toggles, POI callout, and the attribution strip that must be
/// visible wherever these POIs are shown (ODbL — "POI © OpenStreetMap contributors").
struct MapScreen: View {
    @Environment(\.poiStore) private var store
    @Environment(POISync.self) private var sync
    @State private var model: MapViewModel?
    @State private var surface = MapLibreSurface()

    var body: some View {
        ZStack {
            MapSurfaceView(surface: surface)
                .ignoresSafeArea()
                .accessibilityIdentifier("map.surface")

            if let model {
                overlays(model)
            }
        }
        .task {
            if model == nil {
                let m = MapViewModel(store: store, sync: sync)
                m.attach(surface)
                model = m
                await m.start()
            }
        }
    }

    @ViewBuilder
    private func overlays(_ model: MapViewModel) -> some View {
        VStack(alignment: .trailing, spacing: Metrics.Space.sm) {
            HStack {
                Spacer()
                LayerToggle(title: "map.layer.fuel", tint: POIType.fuel.tint, isOn: model.isEnabled(.fuel)) {
                    Task { await model.toggle(.fuel) }
                }
                .accessibilityIdentifier("map.layer.fuel")
            }
            Spacer()
            if let poi = model.selected {
                POICallout(poi: poi) { model.dismissSelection() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("map.callout")
            }
            HStack(alignment: .bottom) {
                AttributionStrip(syncPhase: model.syncPhase, count: model.markers.count)
                Spacer()
            }
        }
        .padding(Metrics.Space.md)
        .animation(Metrics.Motion.entrance, value: model.selected?.id)
    }
}

// MARK: - Pieces

private struct LayerToggle: View {
    let title: LocalizedStringResource
    let tint: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.sm) {
                Circle().fill(isOn ? tint : Palette.muted2).frame(width: 8, height: 8)
                Text(title)
            }
            .font(Typography.mono(11, weight: .semibold))
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(isOn ? tint : Palette.muted)
            .padding(.horizontal, Metrics.Space.md)
            .frame(minHeight: 44)
            .background(Palette.deep.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(isOn ? tint.opacity(0.5) : Palette.hairStrong, lineWidth: Metrics.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct POICallout: View {
    let poi: POIRecord
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.md) {
            Circle().fill(poi.type.tint).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: Metrics.Space.xs) {
                Text(poi.name)
                    .font(Typography.display(16))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 0) {
                    Text(poi.type.label).foregroundStyle(poi.type.tint)
                    if let district = poi.district, !district.isEmpty {
                        Text(verbatim: " · ").foregroundStyle(Palette.muted2)
                        Text(district).foregroundStyle(Palette.muted)
                    }
                }
                .font(Typography.mono(10))
                if let phone = poi.phone, !phone.isEmpty, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                    Link(destination: url) {
                        Label { Text(phone) } icon: { Image(systemName: "phone.fill") }
                            .font(Typography.mono(11, weight: .semibold))
                            .foregroundStyle(Palette.teal)
                    }
                    .padding(.top, Metrics.Space.xs)
                }
            }
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("common.close"))
        }
        .padding(.leading, Metrics.Space.lg)
        .padding(.vertical, Metrics.Space.md)
        .background(Palette.deep.opacity(0.96), in: RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
    }
}

/// ODbL obligation: OSM attribution must be visible wherever the POIs are. Also carries the sync state.
private struct AttributionStrip: View {
    let syncPhase: POISync.Phase
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch syncPhase {
            case .syncing:
                Text("map.sync.syncing").foregroundStyle(Palette.teal)
            case .failed:
                Text("map.sync.failed").foregroundStyle(Palette.amber)
            case .idle:
                Text("map.places.count \(count)").foregroundStyle(Palette.muted2)
            }
            Text("map.attribution")
                .foregroundStyle(Palette.muted)
                .accessibilityIdentifier("map.attribution")
        }
        .font(Typography.mono(9))
        .padding(.horizontal, Metrics.Space.sm + 2)
        .padding(.vertical, Metrics.Space.xs + 1)
        .background(Palette.abyss.opacity(0.78), in: RoundedRectangle(cornerRadius: Metrics.Radius.xs, style: .continuous))
    }
}
