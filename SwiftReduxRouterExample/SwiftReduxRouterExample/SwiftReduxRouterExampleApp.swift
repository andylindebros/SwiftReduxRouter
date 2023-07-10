import SwiftUIRedux
import SwiftReduxRouter
import SwiftUI

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
                        guard let deepLinkAction = NavigationActions.Deeplink(with: incomingURL) else { return }
                        store.dispatch(deepLinkAction)
                    }
                }
        }
    }
}
