import SwiftRouter
import SwiftUI
import SwiftUIRedux

@main
struct SwiftReduxRouterExampleApp: App {
    let store: Store<AppState>
    let routes: [Navigation.RouterView.Config]
    init() {
        let store = AppState.createStore(initState: AppState(
            main: MainState(),
            navigation: Navigation.State(observed: .init(
                navigationModels: [
                    Navigation.Model.create(
                        id: AppState.tabOne,
                        selectedPath: ContentView.navigationRoutes.first!
                            .reverse(params: ["name": .int(1)])!,
                        tab: Navigation.Tab(
                            name: "First Tab",
                            icon: Navigation.Tab.Icon.system(name: "star.fill")
                        )
                    ),
                    Navigation.Model.create(
                        id: AppState.tabTwo,
                        selectedPath: ContentView.navigationRoutes.last!
                            .reverse(params: ["name": .int(1)])!,
                        tab: Navigation.Tab(
                            name: "Second Tab",
                            icon: Navigation.Tab.Icon.iconImage(id: "heart.fill"),
                            badgeColor: .red
                        )
                    ),
                ]
            ))
        ))

        let routes = ContentView.routes(store: store)
        Task {
            await store.dispatch(Navigation.Action.setAvailableRoutes(to: routes.map { $0.routes }.flatMap { $0 }))
        }
        self.routes = routes
        self.store = store
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigationState: store.state.navigation, routes: routes, dispatch: store.dispatch)
                .onOpenURL { incomingURL in
                    Task {
                        guard let deepLinkAction = Navigation.Action.Deeplink(with: incomingURL, accessLevel: .public)?.action(for: store.state.navigation.state) as? Navigation.Action else { return }
                        await store.dispatch(deepLinkAction)
                    }
                }
        }
    }
}
