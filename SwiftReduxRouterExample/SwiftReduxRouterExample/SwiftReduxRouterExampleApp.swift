import SwiftReduxRouter
import SwiftUI
import SwiftUIRedux

@main
struct SwiftReduxRouterExampleApp: App {
    let store: Store<AppState>
    let routes: [RouterView.Route]
    init() {
        let store = AppState.createStore(initState: AppState(
            main: MainState(),
            navigation: Navigation.State(observed: .init(
                navigationModels: [
                    NavigationModel.createInitModel(
                        id: AppState.tabOne,
                        selectedPath: ContentView.navigationRoutes.first!
                            .reverse(params: ["name": .int(1)])!,
                        tab: NavigationTab(
                            name: "First Tab",
                            icon: NavigationTab.Icon.system(name: "star.fill")
                        )
                    ),
                    NavigationModel.createInitModel(
                        id: AppState.tabTwo,
                        selectedPath: ContentView.navigationRoutes.last!
                            .reverse(params: ["name": .int(1)])!,
                        tab: NavigationTab(
                            name: "Second Tab",
                            icon: NavigationTab.Icon.iconImage(id: "heart.fill"),
                            badgeColor: .red
                        )
                    ),
                ]
            ))
        ))

        let routes = ContentView.routes(store: store)
        Task {
            await store.dispatch(NavigationAction.setAvailableRoutes(to: routes.map { $0.paths }.flatMap { $0 }))
        }
        self.routes = routes
        self.store = store
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigationState: store.state.navigation, routes: routes, dispatch: store.dispatch)
                .onOpenURL { incomingURL in
                    Task {
                        guard let deepLinkAction = NavigationAction.Deeplink(with: incomingURL) else { return }
                        await store.dispatch(NavigationAction.deeplink(deepLinkAction))
                    }
                }
        }
    }
}
