import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appModel.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                }

                Section("Subscription") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(store.isPro ? "Pro" : "Free")
                            .foregroundStyle(store.isPro ? OpenlaterColor.wax : OpenlaterColor.inkMuted)
                    }
                    if !store.isPro {
                        Button("Upgrade to Pro") { showingPaywall = true }
                    } else {
                        Button("Manage subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                }

                Section("Your capsules") {
                    HStack {
                        Text("Sealed / total")
                        Spacer()
                        Text("\(appModel.capsules.count)")
                            .foregroundStyle(OpenlaterColor.inkMuted)
                    }
                    if !store.isPro {
                        Text("Free tier: up to 3 capsules, text only.")
                            .font(.footnote)
                            .foregroundStyle(OpenlaterColor.inkMuted)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% on-device")
                            .foregroundStyle(OpenlaterColor.inkMuted)
                    }
                    Text("Every letter, photo, and voice memo is stored only on this device. Nothing is ever uploaded, synced, or sent anywhere.")
                        .font(.footnote)
                        .foregroundStyle(OpenlaterColor.inkMuted)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }
}
