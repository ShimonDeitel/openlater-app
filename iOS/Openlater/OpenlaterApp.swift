import SwiftUI
import SwiftData

@main
struct OpenlaterApp: App {
    @StateObject private var store: Store
    @StateObject private var appModel: AppModel
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let c = AppModel.makeContainer()
        let s = Store()
        let m = AppModel(container: c)
        m.store = s
        self.container = c
        _store = StateObject(wrappedValue: s)
        _appModel = StateObject(wrappedValue: m)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appModel)
                .modelContainer(container)
                .preferredColorScheme(appModel.theme.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    // Re-check every capsule's unlock state whenever the app becomes
                    // active — this is what makes the lock genuinely date-driven
                    // rather than dependent on the app happening to be open at the
                    // unlock instant.
                    if phase == .active {
                        appModel.reload()
                        appModel.sweepReseals()
                    }
                }
        }
    }
}
