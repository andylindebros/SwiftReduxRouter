import SwiftReduxRouter
import SwiftUI

enum AppRoutes: String, CaseIterable {
    static let names = ["Cars", "Houses", "Bikes", "Toys", "Tools", "Furniture", "Jobs"]

    static let backgrounds = [Color.red, Color.pink, Color.yellow, Color.green, Color.purple]

    case viewControllerRoute
    case helloWorld = "hello/<string:name>"

    var navigationRoute: NavigationRoute {
        NavigationRoute(rawValue)
    }

    var route: RouterView.Route {
        switch self {
        case .viewControllerRoute:
            return RouterView.Route(
                route: navigationRoute,
                renderController: { _, _, _ in
                    MyViewController()
                }
            )
        case .helloWorld:
            return RouterView.Route(
                route: navigationRoute,
                renderView: { session, params, _ in
                    let presentedName = params["name"] as? String ?? "not known"
                    let name = Self.names.randomElement() ?? "unknown"
                    return AnyView(
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                Spacer()

                                Text("Presenting \(presentedName)")
                                    .font(.system(size: 50)).bold()
                                    .foregroundColor(.black)
                                Button(action: {
                                    AppStore.shared.store.dispatch(
                                        NavigationActions.Push(
                                            path: navigationRoute.reverse(params: ["name": name])!,
                                            target: session.name
                                        )
                                    )
                                }) {
                                    Text("Push \(name) to current session").foregroundColor(.black)
                                }
                                Button(action: {
                                    AppStore.shared.store.dispatch(
                                        NavigationActions.Push(
                                            path: navigationRoute.reverse(params: ["name": name])!,
                                            target: "tab1"
                                        )
                                    )
                                }) {
                                    Text("Push \(name) to Tab 1").foregroundColor(.black)
                                }

                                Button(action: {
                                    AppStore.shared.store.dispatch(
                                        NavigationActions.Push(
                                            path: navigationRoute.reverse(params: ["name": name])!,
                                            target: "tab2"
                                        )
                                    )
                                }) {
                                    Text("Push \(name) to Tab 2").foregroundColor(.black)
                                }

                                Button(action: {
                                    AppStore.shared.store.dispatch(
                                        NavigationActions.Push(
                                            path: navigationRoute.reverse(params: ["name": name])!,
                                            target: UUID().uuidString
                                        )
                                    )
                                }) {
                                    Text("Present \(name)").foregroundColor(.black)
                                }
                                Spacer()
                            }
                            Spacer()
                        }

                        .background(Self.backgrounds.randomElement() ?? Color.white)

                        .navigationTitle("\(presentedName)")
                        .navigationBarItems(trailing: Button(action: {
                            AppStore.shared.store.dispatch(
                                NavigationActions.Dismiss(target: session.name)
                            )
                        }) {
                            Text(session.tab == nil ? "Close" : "")
                        })

                        .background(Self.backgrounds.randomElement() ?? Color.white)
                    )
                }
            )
        }
    }
}

class MyController: UIViewController, UIRouteViewController {
    var session: NavigationSession?
}
