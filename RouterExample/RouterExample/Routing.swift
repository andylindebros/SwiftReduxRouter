import SwiftUI
import SwiftRouter
import NiceToHave
import Dependencies

enum Routing {

    static let routes = [
        Routing.Route.configure()
    ]

    static let firstTabNavigaionModel = SwiftRouter.Model.create(
        id: UUID(),
        routes: Array {
            Routing.Route.navigationRoute
        },
        selectedPath: Routing.Route.path()!,
        tab: .init(
            name: "First",
            icon: .system(name: "house"),
            selectedIcon: .system(name: "house.fill")
        )
    )

    static let secondTabNavigaionModel = SwiftRouter.Model.create(
        id: UUID(),
        routes: Array {
            Routing.Route.navigationRoute
        },
        selectedPath: Routing.Route.path()!,
        tab: .init(
            name: "Second",
            icon: .system(name: "person"),
            selectedIcon: .system(name: "person.fill")
        )
    )

    struct RootView: View {

        init(
            routes: [SwiftRouter.RouterView.Config] = Routing.routes
        ) {
            self.routes = routes

            @Dependency(\.router) var router
            self.router = router as! SwiftRouter.RouterImpl
        }

        let routes: [SwiftRouter.RouterView.Config]
        @ObservedObject var router: SwiftRouter.RouterImpl

        var body: some View {
            SwiftRouter.RouterView(
                navigationState: router.state,
                routes: routes,
                dispatch: { action in
                    guard let action = action as? SwiftRouter.Action else { return }
                    router.dispatch(action)
                }
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}

public extension DependencyValues {
    var router: SwiftRouter.Router {
        get { self[RouterInjectionKey.self] }
        set { self[RouterInjectionKey.self] = newValue }
    }
}

private struct RouterInjectionKey: DependencyKey {
    @MainActor static var liveValue: SwiftRouter.Router = SwiftRouter.RouterImpl(initState: SwiftRouter.State(
        observed: .init(
            navigationModels: [
                Routing.firstTabNavigaionModel,
                Routing.secondTabNavigaionModel
            ],
            availableRoutes: Routing.routes.map { $0.routes }.flatMap { $0 }
        ),

    ), logger: Logger(prefix: "🧭"))
}

extension Logger: @retroactive SwiftRouter.Logger {}


