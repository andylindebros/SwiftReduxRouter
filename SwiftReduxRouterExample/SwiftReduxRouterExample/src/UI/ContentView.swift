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
                    paths: Self.navigationRoutes,
                    renderView: { path, navigationModel, params in
                        let presentedName = params?["name"] as? Int ?? 0
                        let next = presentedName + 1
                        return AnyView(
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
                                                    NavigationActions.Push(
                                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                        to: .current()
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
                                        }
                                        VStack {
                                            Button(action: {
                                                dispatch(NavigationActions.SetBadgeValue(of: navigationModel.id, withValue: "\((Int(navigationState.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) - 1)", withColor: [.red, .blue, .yellow, .purple, .green].randomElement()))
                                            }) {
                                                Text("Decrease badgeValue")
                                            }
                                            Button(action: {
                                                dispatch(NavigationActions.SetBadgeValue(of: navigationModel.id, withValue: "\((Int(navigationState.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) + 1)", withColor: [.red, .blue, .yellow, .purple, .green].randomElement()))
                                            }) {
                                                Text("Increase badgeValue")
                                            }

                                            Button(action: {
                                                dispatch(NavigationActions.SetBadgeValue(of: navigationModel.id, withValue: nil, withColor: nil))
                                            }) {
                                                Text("Reset badge")
                                            }
                                        }
                                        VStack {
                                            Button(action: {
                                                dispatch(
                                                    NavigationActions.Push(
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
                                                    NavigationActions.Replace(
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
