import SwiftUI

/// Explains why location helps *before* the system prompt (SPEC §10 flow steps 1–2, HIG in-context asks).
/// Granted → district resolved on-device and done. Declined → the picker with honest framing.
struct LocationPrimerSheet: View {
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var showPicker = false
    @State private var pickerFraming: DistrictPickerSheet.Framing = .general
    /// Called with the resolved district so the host can, say, recentre the map.
    var onResolved: ((District) -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.Space.xl) {
                VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                    Eyebrow(text: "location.eyebrow", tint: Palette.teal)
                    Text("location.title")
                        .font(Typography.display(26))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("location.body")
                    .font(Typography.body(15))
                    .foregroundStyle(Palette.ink.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: Metrics.Space.md) {
                    Image(systemName: "lock.fill").foregroundStyle(Palette.teal).font(.system(size: 12, weight: .semibold))
                    Text("location.privacy")
                        .font(Typography.body(13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(spacing: Metrics.Space.md) {
                    Button { Task { await locate() } } label: {
                        Label { Text("location.allow") } icon: { Image(systemName: "location.fill") }
                    }
                    .buttonStyle(.prominent)
                    .accessibilityIdentifier("location.allow")
                    Button { pickerFraming = .general; showPicker = true } label: { Text("location.chooseInstead") }
                        .buttonStyle(.outline)
                        .accessibilityIdentifier("location.chooseInstead")
                }
            }
            .padding(Metrics.Space.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.abyss.ignoresSafeArea())
            .disabled(isWorking)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                }
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: { if districts.district != nil { dismiss() } }) {
            DistrictPickerSheet(framing: pickerFraming)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func locate() async {
        isWorking = true
        defer { isWorking = false }
        switch await districts.locate() {
        case .resolved(let district):
            onResolved?(district)
            dismiss()
        case .denied, .unresolved:
            // Honest fallback (SPEC §10 step 4): pick a district; nothing is "unavailable".
            pickerFraming = .afterDecline
            showPicker = true
        }
    }
}
