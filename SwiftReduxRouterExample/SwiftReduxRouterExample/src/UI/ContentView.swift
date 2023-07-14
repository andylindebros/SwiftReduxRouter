import SwiftReduxRouter
import SwiftUI
import SwiftUIRedux

struct ContentView: View {
    @ObservedObject var navigationState: NavigationState

    var dispatch: DispatchFunction

    @MainActor static let navigationRoutes =
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
                    paths: [
                        .init("/custom"),
                    ],
                    render: { _, _, _ in
                        HiddenNavigationBarViewController(rootView: VStack {
                            Text("Custom")
                        })
                    }
                ),
                RouterView.Route(
                    paths: [
                        NavigationRoute("/hello"),
                    ],
                    render: { _, _, _ in
                        RouteViewController(rootView: Text("/hello"))
                    }
                ),
                RouterView.Route(
                    paths: Self.navigationRoutes,
                    render: { _, navigationModel, params in
                        let presentedName = params?["name"] as? Int ?? 0
                        let next = presentedName + 1
                        return RouteViewController(rootView:
                            ScrollView {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Spacer()

                                        VStack {
                                            Text("Presenting \(presentedName)")
                                                .font(.system(size: 50)).bold()
                                                .foregroundColor(.black)
                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.add(
                                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                        to: .current()
                                                    )
                                                )
                                            }) {
                                                Text("Push \(next) to current session").foregroundColor(.black)
                                            }
                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.selectTab(by: AppState.tabOne)
                                                )
                                                dispatch(
                                                    NavigationAction.add(
                                                        path: Self.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                                                        to: .navigationModel(navigationState.navigationModels.first(where: { $0.id == AppState.tabOne })!)
                                                    )
                                                )
                                            }) {
                                                Text("Push \(next) to Tab 1").foregroundColor(.black)
                                            }

                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.selectTab(by: AppState.tabTwo)
                                                )
                                                dispatch(
                                                    NavigationAction.add(
                                                        path: Self.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                                                        to: .navigationModel(navigationState.navigationModels.first(where: { $0.id == AppState.tabTwo })!)
                                                    )
                                                )

                                            }) {
                                                Text("Push \(next) to Tab 2").foregroundColor(.black)
                                            }

                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.add(
                                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                        to: .new()
                                                    )
                                                )
                                            }) {
                                                Text("Present \(next)").foregroundColor(.black)
                                            }
                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.alert(
                                                        .init(
                                                            title: "Awesome!",
                                                            message: "It really works!",
                                                            buttons: [
                                                                .init(
                                                                    label: "Present a view",
                                                                    type: .default,
                                                                    action: NavigationAction.add(
                                                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                                        to: .new()
                                                                    )
                                                                ),
                                                                .init(label: "Cancel", type: .cancel)
                                                            ]
                                                        ))
                                                )
                                            }) {
                                                Text("Present an alert").foregroundColor(.black)
                                            }
                                        }
                                        VStack {
                                            Button(action: {
                                                dispatch(NavigationAction.setBadgeValue(
                                                    to: "\((Int(navigationState.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) - 1)",
                                                    withModelID: navigationModel.id,
                                                    withColor: [.red, .blue, .yellow, .purple, .green].randomElement()
                                                ))
                                            }) {
                                                Text("Decrease badgeValue")
                                            }
                                            Button(action: {
                                                dispatch(NavigationAction.setBadgeValue(
                                                    to: "\((Int(navigationState.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) + 1)",

                                                    withModelID: navigationModel.id,
                                                    withColor: [.red, .blue, .yellow, .purple, .green].randomElement()
                                                ))
                                            }) {
                                                Text("Increase badgeValue")
                                            }

                                            Button(action: {
                                                dispatch(NavigationAction.setBadgeValue(to: nil, withModelID: navigationModel.id, withColor: nil))
                                            }) {
                                                Text("Reset badge")
                                            }
                                        }
                                        VStack {
                                            Button(action: {
                                                dispatch(
                                                    NavigationAction.add(
                                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                        to: .current(animate: false)
                                                    )
                                                )
                                            }) {
                                                Text("Push to current, no animation")
                                            }

                                            Button(action: {
                                                guard let currentNavModel = navigationState.navigationModels.first(where: { $0.id == navigationState.selectedModelId }) else {
                                                    return
                                                }
                                                dispatch(
                                                    NavigationAction.replace(
                                                        path: currentNavModel.selectedPath,
                                                        with: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                        in: currentNavModel
                                                    )
                                                )
                                            }) {
                                                Text("Replace current path with new")
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .background(backgrounds.randomElement() ?? Color.white)

                            .navigationTitle("\(presentedName)")
                            .navigationBarItems(trailing: Button(action: {
                                dispatch(
                                    NavigationAction.dismiss(navigationModel)
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
                    render: { _, _, _ in
                        RouteViewController(rootView: Text("Not found"))
                    },
                    defaultRoute: true
                ),
            ],
            tintColor: .red,
            dispatch: { navigationAction in
                guard let action = navigationAction as? Action else {
                    return
                }
                dispatch(action)
            }
        )
        .edgesIgnoringSafeArea(.all)
        .background(Color.red)
    }
}
