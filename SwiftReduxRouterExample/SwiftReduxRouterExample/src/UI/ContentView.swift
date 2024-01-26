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

    func detentedAction() -> Action {
        NavigationAction.add(
            path: NavigationPath.create("/hello/100")!,
            to: .new(type: .detents([.custom(identifier: "100", height: 200), .medium, .large],
                                    selected: .medium, largestUndimmedDetentIdentifier: PresentationType.Detent.medium, preventDismissal: true, prefersGrabberVisible: true))
        )
    }

    func setDetendedAction(for navigationModel: NavigationModel) -> Action? {
        if #available(iOS 16.0, *) {
            return NavigationAction.selectedDetentChanged(to: UISheetPresentationController.Detent.large().identifier.rawValue, in: navigationModel)
        } else {
            return nil
        }
    }

    var body: some View {
        RouterView(
            navigationState: navigationState,
            navigationControllerRoutes: [
                RouterView.NavigationControllerRoute(
                    paths: [NavigationRoute("test/<string:value>")],
                    render: { _, _ in
                        MyCustomNavigationController()
                    }
                ),
            ],
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
                    paths: [
                        NavigationRoute("/detents"),
                    ],
                    render: { _, _, _ in
                        RouteViewController(rootView: VStack {
                            Text("/detents")

                        })
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
                                            HStack {
                                                Button(action: {
                                                    if let action = setDetendedAction(for: navigationModel) {
                                                        dispatch(action)
                                                    }
                                                }) {
                                                    Text("Set Detended \(next) to large")
                                                }
                                                Button(action: {
                                                    dispatch(detentedAction())
                                                }) {
                                                    Text("Present Detended \(next) to current session")
                                                }

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

                                            HStack {
                                                Button(action: {
                                                    dispatch(
                                                        NavigationAction.add(
                                                            path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                            to: .new(type: .fullscreen, animate: false)
                                                        )
                                                    )
                                                }) {
                                                    Text("Fullscreen \(next)").foregroundColor(.black)
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
                                            }

                                            HStack {
                                                Button(action: {
                                                    dispatch(
                                                        NavigationAction.alert(
                                                            .init(
                                                                type: .actionSheet,
                                                                buttons: [
                                                                    .init(
                                                                        label: "Close and Present view",
                                                                        type: .destructive,
                                                                        actions: [
                                                                            NavigationAction.dismiss(navigationModel),
                                                                            NavigationAction.add(
                                                                                path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                                                                to: .new()
                                                                            ),
                                                                        ]
                                                                    ),
                                                                    .init(
                                                                        label: "Select tab two",
                                                                        type: .destructive,
                                                                        actions: [
                                                                            NavigationAction.dismiss(navigationModel),
                                                                            NavigationAction.selectTab(by: AppState.tabTwo),
                                                                        ]
                                                                    ),
                                                                    .init(label: "Cancel", type: .cancel),
                                                                ]
                                                            ))
                                                    )
                                                }) {
                                                    Text("Present an action sheet").foregroundColor(.black)
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
                                                                    .init(label: "Cancel", type: .cancel),
                                                                ]
                                                            ))
                                                    )
                                                }) {
                                                    Text("Present an alert").foregroundColor(.black)
                                                }
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
                            .navigationBarItems(
                                leading: Button(action: {
                                    dispatch(NavigationAction.prepareAndDismiss(navigationModel, animated: true, completionAction: NavigationAction.add(
                                        path: Self.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                        to: .new()
                                    )))
                                }) { Text("Prepare") },

                                trailing: Button(action: {
                                    dispatch(
                                        NavigationAction.dismiss(navigationModel)
                                    )
                                }) {
                                    Text(navigationModel.tab == nil ? "Close" : "")
                                }
                            )

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
