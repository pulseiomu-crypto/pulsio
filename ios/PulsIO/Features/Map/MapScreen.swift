import SwiftUI

/// The map screen: full-bleed map, layer toggles, POI callout, and the attribution strip that must be
/// visible wherever these POIs are shown (ODbL — "POI © OpenStreetMap contributors").
struct MapScreen: View {
    @Environment(\.poiStore) private var store
    @Environment(POISync.self) private var sync
    @Environment(SessionStore.self) private var session
    @Environment(DistrictStore.self) private var districts
    @Environment(PulseStore.self) private var pulses
    @Environment(AccessGate.self) private var gate
    @Environment(PulseFXController.self) private var pulseFX
    @Environment(PulseResultStore.self) private var result
    @Environment(ScoreStore.self) private var scores
    @State private var showScore = false
    @State private var showShare = false
    @State private var model: MapViewModel?
    @State private var surface = MapLibreSurface(basemap: UserDefaults.standard.string(forKey: Basemap.defaultsKey).flatMap(Basemap.init(rawValue:)) ?? .default)
    @State private var showPrimer = false
    @State private var showPicker = false
    @State private var showSpent = false
    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        PulsePanelHost(content: {
            ZStack {
                MapSurfaceView(surface: surface)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("map.surface")

                PulseFXOverlay(controller: pulseFX, button: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY),
                               buttonInner: PulseDock.buttonSize / 2 - PulseDock.bezel)

                if let model {
                    overlays(model)
                }
            }
        }, onTap: { row in
            // Rows tap through to the map (SPEC §14); the panel steps aside so the island is visible.
            switch row.tap {
            case "map": result.isPresented = false
            case "score": showScore = true
            default: break
            }
        }, onShare: { showShare = true })
        .coordinateSpace(.named("mapScreen"))
        .overlayPreferenceValue(PulseButtonAnchor.self) { anchor in
            GeometryReader { proxy in
                Color.clear.onChange(of: anchor.map { proxy[$0] }, initial: true) { _, rect in
                    if let rect { buttonFrame = rect }
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSpent) { PulseSpentSheet() }
        .sheet(isPresented: $showScore) { PulsScoreScreen() }
        .sheet(isPresented: $showShare) {
            #if DEBUG
            // Design/QA hook: include a sample community report card (reports aren't built yet).
            if ProcessInfo.processInfo.environment["SHARE_REPORT_SAMPLE"] == "1" {
                ShareCardsSheet(preselected: [.pulseResult, .pulsScore, .report], report: ReportCardModel(
                    category: "Flooding", description: "Royal Road under 30 cm of water outside the Winners at Belle Rose — traffic diverted via Ebène.",
                    district: .plainesWilhems, confirmations: 4, createdAt: .now, symbol: "water.waves"))
            } else {
                ShareCardsSheet(preselected: [.pulseResult, .pulsScore])
            }
            #else
            ShareCardsSheet(preselected: [.pulseResult, .pulsScore])
            #endif
        }
        .onChange(of: session.isSignedIn, initial: true) { _, _ in Task { await pulses.refresh() } }
        .task {
            if model == nil {
                let m = MapViewModel(store: store, sync: sync, session: session)
                m.attach(surface)
                pulseFX.attach(surface)
                Task { await scores.refresh() }
                m.showUserLocation(districts.locationAvailability == .authorized)
                model = m
                await m.start()
                #if DEBUG
                // Design/QA hook: start the camera somewhere specific ("lat,lng,zoom"). Debug builds only.
                if let spec = ProcessInfo.processInfo.environment["MAP_CAMERA"] {
                    let parts = spec.split(separator: ",").compactMap { Double($0) }
                    if parts.count == 3 { surface.setCamera(MapCamera(latitude: parts[0], longitude: parts[1], zoom: parts[2]), animated: false) }
                }
                // Design/QA hook: play the ceremony without spending a pulse. Debug builds only.
                if ProcessInfo.processInfo.environment["PULSEFX_PREVIEW"] == "1" {
                    try? await Task.sleep(for: .seconds(2))
                    pulseFX.fire(markers: m.markers, viewport: UIScreen.main.bounds.size, onReveal: {}, onDone: {})
                }
                #endif
            }
        }
        .onChange(of: session.emergency.isActive) { _, active in
            Task { await model?.emergencyDidChange(active) }
        }
        .onChange(of: districts.locationAvailability) { _, availability in
            model?.showUserLocation(availability == .authorized)
        }
        .sheet(isPresented: $showPrimer) {
            LocationPrimerSheet { _ in Task { await recentreOnUser() } }
        }
        .sheet(isPresented: $showPicker) {
            DistrictPickerSheet(framing: .general)
        }
    }

    /// The locate button: the in-context point of first use for the permission (SPEC §10 flow step 2).
    private func locateTapped() {
        switch districts.locationAvailability {
        case .notDetermined:
            showPrimer = true
        case .denied, .restricted:
            showPicker = true
        case .authorized:
            Task {
                if case .resolved = await districts.locate() { await recentreOnUser() }
            }
        }
    }

    private func recentreOnUser() async {
        // The map's own blue dot has the position; we only nudge the camera toward it via the SDK's
        // user-location annotation, so the coordinate never passes through app code that could keep it.
        model?.showUserLocation(true)
        if let coordinate = surface.mapView.userLocation?.coordinate, coordinate.latitude != 0 || coordinate.longitude != 0 {
            model?.centre(on: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    @ViewBuilder
    private func overlays(_ model: MapViewModel) -> some View {
        VStack(alignment: .trailing, spacing: Metrics.Space.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                    DistrictChip(district: districts.district, source: districts.source) {
                        if districts.district == nil, districts.locationAvailability == .notDetermined { showPrimer = true } else { showPicker = true }
                    }
                    .accessibilityIdentifier("map.district")
                    ScorePill(breakdown: scores.breakdown) { showScore = true }
                        .accessibilityIdentifier("map.score")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Metrics.Space.sm) {
                    LayerToggle(title: "map.layer.fuel", tint: POIType.fuel.tint, isOn: model.isEnabled(.fuel)) {
                        Task { await model.toggle(.fuel) }
                    }
                    .accessibilityIdentifier("map.layer.fuel")
                    Button(action: locateTapped) {
                        Image(systemName: districts.locationAvailability == .authorized ? "location.fill" : "location")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(districts.locationAvailability == .authorized ? Palette.sky : Palette.muted)
                            .frame(width: 44, height: 44)
                            .background(Palette.deep.opacity(0.92), in: Circle())
                            .overlay(Circle().stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("location.locateMe"))
                    .accessibilityIdentifier("map.locate")
                    BasemapSwitcher(selected: model.basemap) { model.setBasemap($0) }
                }
            }
            Spacer()
            if let poi = model.selected {
                POICallout(poi: poi) { model.dismissSelection() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("map.callout")
            }
            HStack(alignment: .bottom) {
                Spacer()
                PulseDock(controller: pulseFX, onFire: { fire(model) }, onSpent: { showSpent = true })
                Spacer()
            }
            .overlay(alignment: .trailing) {
                if result.hasResult, !result.isPresented, !pulseFX.isRunning {
                    Button { result.isPresented = true } label: {
                        Label { Text("panel.reopen") } icon: { Image(systemName: "waveform.path.ecg") }
                            .font(Typography.mono(10, weight: .semibold))
                            .tracking(0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.teal)
                            .padding(.horizontal, Metrics.Space.md)
                            .frame(minHeight: 44)
                            .background(Palette.deep.opacity(0.92), in: Capsule())
                            .overlay(Capsule().stroke(Palette.hairActive, lineWidth: Metrics.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("panel.reopen")
                }
            }
            .padding(.bottom, Metrics.Space.sm)
            HStack(alignment: .bottom) {
                AttributionStrip(syncPhase: model.syncPhase, count: model.markers.count)
                Spacer()
            }
        }
        .padding(Metrics.Space.md)
        .animation(Metrics.Motion.entrance, value: model.selected?.id)
    }

    /// Fire: gate → spend on the server → ceremony. The map is the ceremony's stage; markers light as the
    /// wavefront reaches them and the frost clears on impact.
    private func fire(_ model: MapViewModel) {
        gate.perform(.firePulse) {
            switch await pulses.fire() {
            case .success:
                model.dismissSelection()
                result.isPresented = false
                pulseFX.fire(markers: model.markers, viewport: UIScreen.main.bounds.size,
                             onReveal: { Task { await result.load(present: false) } },   // fetch while the wave runs
                             onDone: { Task { await pulses.refresh(); await scores.refresh(); if result.hasResult { result.isPresented = true } else { await result.load() } } })
            case .failure(.code(.spent)):
                showSpent = true
            case .failure:
                break   // PulseStore.lastFailure carries it; the dock line shows sign-in/spent states
            }
        }
    }
}

// MARK: - Pieces

/// Three keyless ESRI basemaps (dark default, satellite, street) — a compact vertical pill of symbols.
private struct BasemapSwitcher: View {
    let selected: Basemap
    let onSelect: (Basemap) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Basemap.allCases) { basemap in
                Button { onSelect(basemap) } label: {
                    Image(systemName: basemap.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(basemap == selected ? Palette.teal : Palette.muted)
                        .frame(width: 44, height: 44)
                        .background(basemap == selected ? Palette.teal.opacity(0.14) : .clear, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(basemap.label))
                .accessibilityValue(Text(verbatim: basemap == selected ? "on" : "off"))
                .accessibilityIdentifier("map.basemap.\(basemap.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.deep.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
    }
}

/// The PulsScore pill (FRONTEND §B top bar): score + verdict, tap → PulsScore.
private struct ScorePill: View {
    let breakdown: PulsScoreBreakdown?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.sm) {
                PulsScoreRing(breakdown: breakdown, lineWidth: 3, gapDegrees: 6, showsCentre: false).frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("pulsscore.title").font(Typography.mono(9)).tracking(0.14).textCase(.uppercase).foregroundStyle(Palette.muted2)
                        Text(breakdown.map { String($0.score) } ?? "—").font(Typography.body(13, weight: .semibold)).foregroundStyle(Palette.teal).monospacedDigit()
                    }
                    if let verdict = breakdown?.verdict {
                        Text(verdict.label).font(Typography.mono(9)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, Metrics.Space.md)
            .frame(minHeight: 44)
            .background(Palette.deep.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
        }
        .buttonStyle(.plain)
    }
}

/// "Where you are" — the one location field, and how it was set. Tap to change it (SPEC §10 step 5).
private struct DistrictChip: View {
    let district: District?
    let source: DistrictStore.Source?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.sm) {
                Image(systemName: source == .gps ? "location.fill" : "mappin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(district == nil ? Palette.amber : Palette.teal)
                VStack(alignment: .leading, spacing: 1) {
                    if let district {
                        Text(district.label).font(Typography.body(13, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(source == .gps ? "district.source.gps" : "district.source.manual")
                            .font(Typography.mono(9)).tracking(0.1).textCase(.uppercase).foregroundStyle(Palette.muted2)
                    } else {
                        Text("district.chip.unset").font(Typography.body(13, weight: .medium)).foregroundStyle(Palette.ink)
                        Text("district.chip.unset.hint").font(Typography.mono(9)).textCase(.uppercase).foregroundStyle(Palette.muted2)
                    }
                }
            }
            .padding(.horizontal, Metrics.Space.md)
            .frame(minHeight: 44)
            .background(Palette.deep.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
        }
        .buttonStyle(.plain)
    }
}

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
