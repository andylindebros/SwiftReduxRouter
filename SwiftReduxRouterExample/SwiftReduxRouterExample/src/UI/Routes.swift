import SwiftReduxRouter
import SwiftUI

enum AppRoutes: CaseIterable {
    static let names = ["Alejandro", "Camila", "Diego", "Luciana", "Luis", "Sofía"]

    static let backgrounds = [Color.red, Color.pink, Color.yellow, Color.green, Color.purple]

    case root
    case helloWorld

    var route: RouterView.Route {
        switch self {
        case .root:
            return RouterView.Route(
                path: "root",
                render: { _, _, _ in
                    AnyView(
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Button(action: {
                                    AppStore.shared.store.dispatch(
                                        NavigationActions.Push(
                                            path: NavigationPath("hello/\(Self.names.randomElement() ?? "unknown")"),
                                            target: "presented"
                                        )
                                    )
                                }) {
                                    Text("Open Helloworld")
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .navigationTitle("Main")
                        .background(Self.backgrounds.randomElement() ?? Color.white)
                    )
                }
            )
        case .helloWorld:
            return RouterView.Route(
                path: "hello/<string:name>",
                render: { _, params, _ in

                    let name = params["name"] as? String ?? "sunknwon"
                    return AnyView(
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Text("Hello \(name)")
                                HStack {
                                    Button(action: {
                                        AppStore.shared.store.dispatch(
                                            NavigationActions.GoBack(
                                                target: "presented",
                                                destination: .root
                                            )
                                        )
                                    }) {
                                        Text("Back to befinning")
                                    }
                                    Button(action: {
                                        AppStore.shared.store.dispatch(
                                            NavigationActions.GoBack(
                                                target: "presented",
                                                destination: .back
                                            )
                                        )
                                    }) {
                                        Text("Back")
                                    }
                                    Button(action: {
                                        AppStore.shared.store.dispatch(
                                            NavigationActions.Push(
                                                path: NavigationPath("hello/\(Self.names.randomElement() ?? "unknown")"),
                                                target: "presented"
                                            )
                                        )
                                    }) {
                                        Text("Next")
                                    }
                                }.padding(.top, 20)
                                Spacer()
                            }
                            Spacer()
                        }
                        .navigationTitle("Hello \(name)")
                        .navigationBarItems(trailing: Button(action: {
                            AppStore.shared.store.dispatch(
                                NavigationActions.Push(
                                    path: NavigationPath(RouterView.dismissActionIdentifier),
                                    target: "presented"
                                )
                            )
                        }) {
                            Text("Close")
                        })

                        .background(Self.backgrounds.randomElement() ?? Color.white)
                    )
                }
            )
        }
    }
}

class MyController<Content: View>: RouteViewController<Content> {
    override func configureBeforePushed() {}
}
