import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var store: Store
    @State private var showingCreate = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var selectedCapsule: LetterCapsule?

    var body: some View {
        NavigationStack {
            ZStack {
                OpenlaterColor.paper.ignoresSafeArea()
                if appModel.capsules.isEmpty {
                    emptyState
                } else {
                    capsuleList
                }
            }
            .navigationTitle("Openlater")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(OpenlaterColor.ink)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if appModel.canCreateMore {
                            showingCreate = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(OpenlaterColor.wax)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateCapsuleView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(item: $selectedCapsule) { capsule in
                CapsuleDetailView(capsule: capsule)
            }
        }
        .tint(OpenlaterColor.wax)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            WaxSealView(phase: .intact, size: 120)
            Text("No capsules yet")
                .font(OpenlaterFont.serifHeadline())
                .foregroundStyle(OpenlaterColor.ink)
            Text("Seal a letter for a birthday, an anniversary,\nor any day worth waiting for.")
                .font(OpenlaterFont.body(14))
                .multilineTextAlignment(.center)
                .foregroundStyle(OpenlaterColor.inkMuted)
            Button("Write your first letter") { showingCreate = true }
                .letterButton()
                .frame(maxWidth: 240)
        }
        .padding(32)
    }

    private var capsuleList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(appModel.capsules) { capsule in
                    CapsuleTileView(capsule: capsule)
                        .onTapGesture { selectedCapsule = capsule }
                }
            }
            .padding(16)
        }
    }
}

/// One tile in the grid: sealed capsules show only the seal + countdown; unlocked
/// capsules show a cracked-open seal preview with the title.
struct CapsuleTileView: View {
    @EnvironmentObject private var appModel: AppModel
    let capsule: LetterCapsule

    var body: some View {
        let state = appModel.state(for: capsule)
        PaperCard {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    WaxSealView(phase: state == .sealed ? .intact : .open, size: 64)
                    Spacer()
                }
                Text(capsule.title.isEmpty ? "Untitled letter" : capsule.title)
                    .font(OpenlaterFont.serifHeadline(15))
                    .foregroundStyle(OpenlaterColor.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)

                if state == .sealed {
                    CountdownPill(unlockDate: capsule.unlockDate, now: appModel.clock.now())
                } else {
                    HStack(spacing: 4) {
                        Text(state == .readyToBreak ? "Ready to open" : "Opened")
                            .font(OpenlaterFont.mono(11))
                            .foregroundStyle(OpenlaterColor.wax)
                        if capsule.recurrence != .none {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundStyle(OpenlaterColor.gold)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
