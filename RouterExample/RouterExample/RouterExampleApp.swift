import SwiftUI
import SwiftRouter
import Dependencies

@main
struct RouterExampleApp: App {
    var body: some Scene {
        WindowGroup {
            Routing.RootView()
        }
    }
}
