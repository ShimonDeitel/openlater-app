import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                OpenlaterColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        WaxSealView(phase: .intact, size: 100)
                        Text("Openlater Pro")
                            .font(OpenlaterFont.serifTitle())
                            .foregroundStyle(OpenlaterColor.ink)
                        Text("For letters that keep coming back")
                            .font(OpenlaterFont.body(15))
                            .foregroundStyle(OpenlaterColor.inkMuted)

                        VStack(alignment: .leading, spacing: 14) {
                            featureRow("infinity", "Unlimited capsules", "No cap at 3 — seal as many as you like")
                            featureRow("photo", "Photo capsules", "Seal a photo alongside your words")
                            featureRow("waveform", "Voice-memo capsules", "Record your own voice for the future")
                            featureRow("arrow.triangle.2.circlepath", "Recurring capsules", "A yearly birthday letter that re-seals itself")
                        }
                        .padding(18)
                        .background(OpenlaterColor.paperPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        Button {
                            Task { if await store.purchase() { dismiss() } }
                        } label: {
                            if store.purchaseInFlight {
                                ProgressView().tint(.white)
                            } else {
                                Text("Subscribe — \(store.displayPrice)/month")
                            }
                        }
                        .letterButton()

                        Button("Restore purchases") {
                            Task { await store.restore() }
                        }
                        .font(OpenlaterFont.mono(13))
                        .foregroundStyle(OpenlaterColor.inkMuted)

                        Text("Cancel anytime in the App Store. Payment charged to your Apple ID.")
                            .font(.system(size: 11))
                            .foregroundStyle(OpenlaterColor.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(OpenlaterColor.wax)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(OpenlaterFont.serifHeadline(15)).foregroundStyle(OpenlaterColor.ink)
                Text(subtitle).font(OpenlaterFont.body(13)).foregroundStyle(OpenlaterColor.inkMuted)
            }
        }
    }
}
