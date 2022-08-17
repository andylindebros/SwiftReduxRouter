import ReSwift
import SwiftReduxRouter
import SwiftUI

struct ContentView: View {
    @ObservedObject var navigationState: NavigationState

    var dispatch: DispatchFunction

    static let navigationRoutes =
        [
            NavigationRoute("hello/<int:name>"),
            NavigationRoute("hello/awesome/<int:name>"),
        ]
    let names = ["Cars", "Houses", "Bikes", "Toys", "Tools", "Furniture", "Jobs"]

    let backgrounds = [Color.red, Color.pink, Color.yellow, Color.green, Color.purple]

    var body: some View {
        RouterView(
            navigationState: navigationState,
            routes: [
                RouterView.Route(
                    paths: Self.navigationRoutes,
                    renderView: { path, navigationModel, params in
                        let presentedName = params?["name"] as? Int ?? 0
                        let next = presentedName + 1
                        return AnyView(
                            HStack {
                                Spacer()
                                VStack(spacing: 10) {
                                    Spacer()

                                    Text("Presenting \(presentedName)")
                                        .font(.system(size: 50)).bold()
                                        .foregroundColor(.black)
                                    Button(action: {
                                        dispatch(
                                            NavigationActions.Push(
                                                path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                to: .current
                                            )
                                        )
                                    }) {
                                        Text("Push \(next) to current session").foregroundColor(.black)
                                    }
                                    Button(action: {
                                        dispatch(
                                            NavigationActions.SelectTab(by: AppState.tabOne)
                                        )
                                        dispatch(
                                            NavigationActions.Push(
                                                path: Self.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                                                to: .navigationModel(navigationState.navigationModels.first(where: { $0.id == AppState.tabOne })!)
                                            )
                                        )
                                    }) {
                                        Text("Push \(next) to Tab 1").foregroundColor(.black)
                                    }

                                    Button(action: {
                                        dispatch(
                                            NavigationActions.SelectTab(by: AppState.tabTwo)
                                        )
                                        dispatch(
                                            NavigationActions.Push(
                                                path: Self.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                                                to: .navigationModel(navigationState.navigationModels.first(where: { $0.id == AppState.tabTwo })!)
                                            )
                                        )

                                    }) {
                                        Text("Push \(next) to Tab 2").foregroundColor(.black)
                                    }

                                    Button(action: {
                                        dispatch(
                                            NavigationActions.Present(
                                                path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!
                                            )
                                        )
                                    }) {
                                        Text("Present \(next)").foregroundColor(.black)
                                    }
                                    Button(action: {
                                        dispatch(
                                            NavigationActions.Present(
                                                path: NavigationPath("does not exist")
                                            )
                                        )
                                    }) {
                                        Text("Present a path that doesn't exist").foregroundColor(.black)
                                    }
                                    Spacer()
                                }
                                Spacer()
                            }

                            .background(backgrounds.randomElement() ?? Color.white)

                            .navigationTitle("\(presentedName)")
                            .navigationBarItems(trailing: Button(action: {
                                dispatch(
                                    NavigationActions.Dismiss(navigationModel: navigationModel)
                                )
                            }) {
                                Text(navigationModel.tab == nil ? "Close" : "")
                            })

                            .background(backgrounds.randomElement() ?? Color.white)
                        )
                    }
                ),
                RouterView.Route(
                    paths: [NavigationRoute("default")],
                    renderView: { navigationPath, navigationModel, _ in
                        AnyView(Text("Not found"))
                    },
                    defaultRoute: true
                ),
            ],
            tintColor: .red,
            setSelectedPath: { navigationModel, navigationPath in
                dispatch(NavigationActions.SetSelectedPath(navigationModel: navigationModel, navigationPath: navigationPath))
            },
            onDismiss: { navigationModel in
                dispatch(NavigationActions.NavigationDismissed(navigationModel: navigationModel))
            }
        )
        .edgesIgnoringSafeArea(.all)
        .background(Color.red)
    }
}
