import SwiftReduxRouter
import SwiftUI
import SwiftUIRedux

@main
struct SwiftReduxRouterExampleApp: App {
    let store: Store<AppState>
    let routes: [RouterView.Route]
    init() {
        store = AppState.createStore(initState: AppState(
            main: MainState(),
            navigation: Navigation.State(observed: .init(
                navigationModels: [
                    NavigationModel.createInitModel(
                        id: AppState.tabOne,
                        path: NavigationPath(URL(string: "/tab1")),
                        selectedPath: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(1)"])!,
                        tab: NavigationTab(
                            name: "First Tab",
                            icon: NavigationTab.Icon.system(name: "star.fill")
                        )
                    ),
                    NavigationModel.createInitModel(
                        id: AppState.tabTwo,
                        path: NavigationPath(URL(string: "/tab2")),
                        selectedPath: ContentView.navigationRoutes.last!.reverse(params: ["name": "\(1)"])!,
                        tab: NavigationTab(
                            name: "Second Tab",
                            icon: NavigationTab.Icon.iconImage(id: "heart.fill"),
                            badgeColor: .red
                        )
                    ),
                ]
                // availableNavigationModelRoutes: [],
                // availableRoutes: ContentView.routes(store: Store<AppState>).map { $0.paths }.flatMap { $0 }
            ))
        ))

        routes = ContentView.routes(store: store)

        store.dispatch(NavigationAction.setAvailableRoutes(to: routes.map { $0.paths }.flatMap { $0 }))
        // store.dispatch(NavigationAction.setAvailableRoutes(to: navigationControllerRoutes.map { $0.paths }.flatMap { $0 }))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigationState: store.state.navigation, routes: routes, dispatch: store.dispatch)
                .onOpenURL { incomingURL in
                    DispatchQueue.main.async {
                        guard let deepLinkAction = NavigationAction.Deeplink(with: incomingURL) else { return }
                        store.dispatch(NavigationAction.deeplink(deepLinkAction))
                    }
                }
        }
    }
}
