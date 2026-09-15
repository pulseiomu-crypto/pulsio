import CoreLocation
import MapLibre
import PhotosUI
import SwiftUI

/// Submission (SPEC §11): category → pin → photo → description → submit. The photo is processed on the device
/// (resize, Vision face/text blur) before anything is uploaded; the model check runs after.
struct ReportFlow: View {
    @Environment(ReportStore.self) private var reports
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    /// Where the map was when Report was tapped — the pin starts here (or at the user's location).
    let startCoordinate: CLLocationCoordinate2D

    private enum Step { case category, pin, photo, details, done }
    @State private var step: Step = .category
    @State private var category: ReportCategory?
    @State private var pin: CLLocationCoordinate2D?
    @State private var original: UIImage?
    @State private var processed: PhotoPipeline.Result?
    @State private var isProcessing = false
    @State private var description = ""
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var outcome: Report?
    @State private var errorKey: LocalizedStringResource?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .category: categoryStep
                case .pin: pinStep
                case .photo: photoStep
                case .details: detailsStep
                case .done: doneStep
                }
            }
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("report.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(step == .done ? "common.done" : "common.cancel") }
                        .accessibilityIdentifier("report.cancel")
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(step != .category && step != .done)
    }

    // MARK: Steps

    private var categoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                Eyebrow(text: "report.step.category", tint: Palette.teal)
                Text("report.category.prompt").font(Typography.display(22)).foregroundStyle(Palette.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Metrics.Space.sm)], spacing: Metrics.Space.sm) {
                    ForEach(ReportCategory.allCases) { c in
                        Button {
                            category = c
                            pin = startCoordinate
                            withAnimation(Metrics.Motion.entrance) { step = .pin }
                        } label: {
                            VStack(spacing: Metrics.Space.sm) {
                                Image(systemName: c.symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.amber)
                                Text(c.label).font(Typography.mono(10)).foregroundStyle(Palette.ink).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("report.category.\(c.rawValue)")
                    }
                }
                ReportFeatureNotice()
            }
            .padding(Metrics.Space.lg)
        }
    }

    private var pinStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Metrics.Space.xs) {
                Eyebrow(text: "report.step.pin", tint: Palette.teal)
                Text("report.pin.prompt").font(Typography.body(14)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.Space.lg)
            ZStack {
                PinPlacementMap(coordinate: Binding(get: { pin ?? startCoordinate }, set: { pin = $0 }))
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                    .accessibilityIdentifier("report.pinMap")
                // The pin: fixed at the centre, the map moves under it.
                Image(systemName: "mappin")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .offset(y: -17)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, Metrics.Space.lg)
            VStack(spacing: Metrics.Space.sm) {
                Text("report.pin.hint").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                Button { withAnimation(Metrics.Motion.entrance) { step = .photo } } label: { Text("report.pin.confirm") }
                    .buttonStyle(.prominent)
                    .accessibilityIdentifier("report.pin.confirm")
            }
            .padding(Metrics.Space.lg)
        }
    }

    private var photoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                Eyebrow(text: "report.step.photo", tint: Palette.teal)
                Text("report.photo.prompt").font(Typography.display(22)).foregroundStyle(Palette.ink)
                Text("report.photo.noPeople").font(Typography.body(13)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("report.photo.noPeople")
                if let processed, let image = UIImage(data: processed.jpeg) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
                        .accessibilityIdentifier("report.photo.preview")
                    Text("report.photo.processed \(processed.facesBlurred) \(processed.textRegionsBlurred) \(processed.jpeg.count / 1024)")
                        .font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                        .accessibilityIdentifier("report.photo.processedLine")
                } else if isProcessing {
                    ProgressView { Text("report.photo.processing") }.font(Typography.mono(11)).tint(Palette.teal).frame(maxWidth: .infinity)
                }
                VStack(spacing: Metrics.Space.md) {
                    if CameraPicker.isAvailable {
                        Button { showCamera = true } label: { Label { Text("report.photo.camera") } icon: { Image(systemName: "camera.fill") } }
                            .buttonStyle(.prominent)
                            .accessibilityIdentifier("report.photo.camera")
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label { Text("report.photo.library") } icon: { Image(systemName: "photo.on.rectangle") }
                            .font(Typography.mono(11, weight: .semibold)).tracking(Typography.eyebrowTracking).textCase(.uppercase)
                            .foregroundStyle(Palette.teal).frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.teal.opacity(0.4), lineWidth: Metrics.hairline))
                    }
                    .accessibilityIdentifier("report.photo.library")
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["REPORT_SAMPLE_PHOTO"] == "1" {
                        Button { Task { await process(Self.samplePhoto()) } } label: { Text(verbatim: "Use sample photo (debug)") }
                            .buttonStyle(.outline)
                            .accessibilityIdentifier("report.photo.sample")
                    }
                    #endif
                }
                Button { withAnimation(Metrics.Motion.entrance) { step = .details } } label: { Text("report.photo.next") }
                    .buttonStyle(.outline)
                    .disabled(processed == nil)
                    .accessibilityIdentifier("report.photo.next")
                Text("report.photo.required").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
            }
            .padding(Metrics.Space.lg)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { Task { await process(image) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { if let image = await item.loadUIImage() { await process(image) } }
        }
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                Eyebrow(text: "report.step.details", tint: Palette.teal)
                Text("report.details.prompt").font(Typography.display(22)).foregroundStyle(Palette.ink)
                TextField(text: $description, prompt: Text("report.details.placeholder").foregroundColor(Palette.muted2), axis: .vertical) { Text("report.details.prompt") }
                    .lineLimit(2...3)
                    .font(Typography.body(15)).foregroundStyle(Palette.ink)
                    .padding(Metrics.Space.md)
                    .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                    .onChange(of: description) { _, v in if v.count > ReportRules.descriptionLimit { description = String(v.prefix(ReportRules.descriptionLimit)) } }
                    .accessibilityIdentifier("report.description")
                Text("report.details.count \(description.count) \(ReportRules.descriptionLimit)").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                if let category, let pin {
                    HStack(spacing: Metrics.Space.sm) {
                        Image(systemName: category.symbol).foregroundStyle(Palette.amber)
                        Text(category.label).font(Typography.body(13, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(verbatim: "·").foregroundStyle(Palette.muted2)
                        Text(String(format: "%.4f, %.4f", pin.latitude, pin.longitude)).font(Typography.mono(10)).foregroundStyle(Palette.muted)
                    }
                }
                ReportFeatureNotice()
                if let errorKey {
                    Text(errorKey).font(Typography.mono(11)).foregroundStyle(Palette.coral).accessibilityIdentifier("report.error")
                }
                Button { Task { await submit() } } label: {
                    if reports.isSubmitting { ProgressView().tint(Palette.abyss) } else { Text("report.submit") }
                }
                .buttonStyle(.prominent)
                .disabled(reports.isSubmitting)
                .accessibilityIdentifier("report.submit")
            }
            .padding(Metrics.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var doneStep: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            Image(systemName: outcome?.status.isLive == true ? "checkmark.seal.fill" : "clock.badge.checkmark")
                .font(.system(size: 48, weight: .light)).foregroundStyle(outcome?.status.isLive == true ? Palette.green : Palette.amber)
            Text(outcome?.status.isLive == true ? "report.done.live" : "report.done.pending")
                .font(Typography.display(22)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                .accessibilityIdentifier("report.done")
            Text(outcome?.status.isLive == true ? "report.done.live.body" : "report.done.pending.body")
                .font(Typography.body(14)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 400)
            Spacer()
            Button { dismiss() } label: { Text("common.done") }.buttonStyle(.prominent)
                .accessibilityIdentifier("report.done.close")
        }
        .padding(Metrics.Space.xl)
    }

    // MARK: Actions

    private func process(_ image: UIImage) async {
        isProcessing = true
        errorKey = nil
        defer { isProcessing = false }
        original = image
        do { processed = try await PhotoPipeline.process(image) } catch { errorKey = "report.error.photo" }
    }

    private func submit() async {
        guard let category, let pin, let processed else { return }
        errorKey = nil
        switch await reports.submit(category: category, description: description.isEmpty ? nil : description, coordinate: pin, photo: processed.jpeg) {
        case .success(let report):
            outcome = report
            withAnimation(Metrics.Motion.entrance) { step = .done }
        case .failure(.code(let code)):
            errorKey = code.messageKey
        case .failure:
            errorKey = "report.error.generic"
        }
    }

    #if DEBUG
    /// A synthetic "flooded road" with a number plate, for the simulator (no camera).
    static func samplePhoto() -> UIImage {
        let size = CGSize(width: 2400, height: 1800)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.35, green: 0.45, blue: 0.5, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.25, green: 0.3, blue: 0.28, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 900, width: 2400, height: 900))
            UIColor(red: 0.55, green: 0.6, blue: 0.62, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 1300, width: 2400, height: 500))
            UIColor.white.setFill(); ctx.fill(CGRect(x: 1500, y: 1350, width: 520, height: 160))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 120), .foregroundColor: UIColor.black]
            ("AB 1234" as NSString).draw(at: CGPoint(x: 1530, y: 1365), withAttributes: attrs)
        }
    }
    #endif
}

/// The pin-placement map: the pin stays centred, the user pans the map beneath it (the "draggable pin").
private struct PinPlacementMap: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleJSON: MapStyle.json(for: .dark))
        map.delegate = context.coordinator
        map.setCenter(coordinate, zoomLevel: 15, animated: false)
        map.allowsRotating = false
        map.allowsTilting = false
        map.logoView.isHidden = true
        map.attributionButtonMargins = CGPoint(x: 8, y: 8)
        return map
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(binding: $coordinate) }

    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        let binding: Binding<CLLocationCoordinate2D>
        init(binding: Binding<CLLocationCoordinate2D>) { self.binding = binding }
        @MainActor func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            binding.wrappedValue = mapView.centerCoordinate
        }
    }
}
