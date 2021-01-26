import SwiftUI
import SwiftReduxRouter

@main
struct SwiftReduxRouterExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: AppStore.shared)
        }
    }
}
