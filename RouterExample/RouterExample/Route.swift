import SwiftRouter
import SwiftUI
import Dependencies

extension Routing {
    enum Route {
        static let paramName = "name"
        static let navigationRoute = SwiftRouter.Route("/hello/<string:\(paramName)>", name: "\(type(of: Self.self))", accessLevel: .public)

        static func path(name: String? = ["Andy", "Carita", "Ruby", "Henry", "Florence"].randomElement(), navBarOptions: SwiftRouter.Path.NavBarOptions? = nil) -> SwiftRouter.Path? {
            navigationRoute.reverse(params: [paramName: .string(name ?? "unknown")], navBarOptions: navBarOptions)
        }

        static func configure() -> SwiftRouter.RouterView.Config {
            .init(
                routes: [navigationRoute],
                render: { viewModel in
                    SwiftRouter.RouteViewController(
                        rootView: RouteView(
                            name: viewModel.path.params?[paramName]?.value()
                        )
                    )
                }
            )
        }
    }
}

extension Routing.Route {
    struct RouteView: View {
        @Dependency(\.router) private var router: SwiftRouter.Router

        let name: String?
        var body: some View {
            ScrollView {
                VStack {
                    Text(name ?? "unknown")

                    Button(action: {
                        router.dispatch(.open(
                            path: Routing.Route.path(),
                            in: .new()
                        ))
                    }) {
                        Text("Present")
                    }
                }
            }
        }
    }
}
