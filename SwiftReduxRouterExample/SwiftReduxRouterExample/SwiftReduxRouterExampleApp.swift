import SwiftReduxRouter
import SwiftUI
import SwiftUIRedux

@main
struct SwiftReduxRouterExampleApp: App {
    let store: Store<AppState>
    init() {
        store = AppState.createStore(initState: AppState.initNavigationState)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigationState: store.state.navigation, dispatch: store.dispatch)
                .onOpenURL { incomingURL in
                    DispatchQueue.main.async {
                        guard let deepLinkAction = NavigationAction.Deeplink(with: incomingURL) else { return }
                        store.dispatch(NavigationAction.deeplink(deepLinkAction))
                    }
                }
        }
    }
}
