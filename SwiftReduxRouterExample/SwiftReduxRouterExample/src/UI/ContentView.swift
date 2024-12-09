import SwiftReduxRouter
import SwiftUI
import SwiftUIRedux

struct RouterViewWrapper: View {
    @ObservedObject var navigationState: Observed<Navigation.State>
    let navigationControllerRoutes: [RouterView.NavigationControllerRoute]
    let routes: [RouterView.Route]
    let tintColor: UIColor
    let tabBarIconImages: [NavigationTab.IconImage]
    let dispatch: NavigationDispatcher

    var body: some View {
        RouterView(navigationState: navigationState.state, navigationControllerRoutes: navigationControllerRoutes, routes: routes, dispatch: dispatch)
    }
}

struct ContentView: View {
    var navigationState: Observed<Navigation.State>

    let routes: [RouterView.Route]
    var dispatch: DispatchFunction

    static let navigationRoutes =
        [
            NavigationRoute("hello/<int:name>"),
            NavigationRoute("hello/awesome/<int:name>"),
        ]
    static let names = ["Cars", "Houses", "Bikes", "Toys", "Tools", "Furniture", "Jobs"]

    static let backgrounds = [Color.red, Color.pink, Color.yellow, Color.green, Color.purple]

    var body: some View {
        RouterViewWrapper(
            navigationState: navigationState,
            navigationControllerRoutes: [
                RouterView.NavigationControllerRoute(
                    paths: [NavigationRoute("test/<string:value>")],
                    render: { _, _ in
                        MyCustomNavigationController()
                    }
                ),
            ],
            routes: routes,
            tintColor: .red,
            tabBarIconImages: [
                NavigationTab.IconImage(id: "heart.fill", image: UIImage(systemName: "heart.fill")!),
            ],
            dispatch: { navigationAction in
                Task {
                    guard let action = navigationAction as? Action else {
                        return
                    }
                    print("Action", action)

                    await dispatch(action)
                }
            }
        )
        .edgesIgnoringSafeArea(.all)
        .background(Color.red)
    }

    static func routes(store: Store<AppState>) -> [RouterView.Route] {
        [
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
                paths: navigationRoutes,
                render: {
                    path,
                    navigationModel,
                    params in
                    let presentedName: Int = params?["name"]?.value() ?? 0
                    let next = presentedName + 1
                    return RouteViewController(rootView:
                        TestRoute(
                            main: store.state.main,
                            navigationPath: path,
                            navigationModel: navigationModel,
                            name: presentedName,
                            next: next,
                            navigationState: store.state.navigation,
                            dispatch: store.dispatch
                        )
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
        ]
    }
}

struct TestRoute: View {
    @ObservedObject var main: Observed<MainState>
    let navigationPath: NavPath
    let navigationModel: NavigationModel
    let name: Int
    let next: Int
    var navigationState: Observed<Navigation.State>
    var dispatch: DispatchFunction

    func detentedAction() -> Action {
        NavigationAction.open(
            path: .create("/hello/100")!,
            in: .new(type: .detents([.custom(identifier: "100", height: 200), .medium, .large],
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
        ScrollView {
            ScrollViewReader { scrollProxy in
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Spacer()

                        VStack {
                            firstSection
                            secondSection
                            thirdSection
                            fourthSection
                            fithSection
                            sixSection
                        }
                    }
                    Spacer()
                }.id("topItem")
                    .onChange(of: main.state.observed.pathScrollToTop) { selectedPath in
                        if selectedPath?.id == navigationPath.id {
                            withAnimation {
                                scrollProxy.scrollTo("topItem", anchor: .top)
                                Task {
                                    await dispatch(MainState.Actions.resetScroll)
                                }
                            }
                        }
                    }
            }
        }
        .background(ContentView.backgrounds.randomElement() ?? Color.white)
        .navigationTitle("\(name)")
        .navigationBarItems(
            leading: Button(action: { Task {
                await dispatch(NavigationAction.dismiss(.navigationModel(navigationModel), withCompletion: NavigationAction.open(
                    path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                    in: .new()
                )))
            }}) { Text("Prepare") },

            trailing: Button(action: { Task {
                await dispatch(
                    NavigationAction.dismiss(.navigationPath(navigationPath))
                )
            }}) {
                Text(navigationModel.tab == nil ? "Close" : "")
            }
        )

        .background(ContentView.backgrounds.randomElement() ?? Color.white)
    }

    var firstSection: some View {
        VStack {
            Text("Presenting \(name)")
                .font(.system(size: 50)).bold()
                .foregroundColor(.black)
            HStack {
                Button(action: { Task {
                    if let action = setDetendedAction(for: navigationModel) {
                        await dispatch(action)
                    }
                }}) {
                    Text("Set Detended \(next) to large")
                }
                Button(action: { Task {
                    await dispatch(detentedAction())
                }}) {
                    Text("Present Detended \(next) to current session")
                }

                Button(action: { Task {
                    await dispatch(
                        NavigationAction.open(
                            path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                            in: .current()
                        )
                    )
                }}) {
                    Text("Push \(next) to current session").foregroundColor(.black)
                }
            }
        }
    }

    var secondSection: some View {
        VStack {
            Button(action: { Task {
                await dispatch(NavigationAction {
                    NavigationAction.selectTab(by: AppState.tabOne)
                    NavigationAction.open(
                        path: ContentView.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                        in: .navigationModel(navigationState.state.observed.navigationModels.first(where: { $0.id == AppState.tabOne })!)
                    )
                })
            }}) {
                Text("Push \(next) to Tab 1").foregroundColor(.black)
            }

            Button(action: {
                Task {
                    await dispatch(NavigationAction.open(path: .create("/custom")!, in: .current()))
                    }
                }
            ) {
                   Text("Open custom")
            }

            Button(action: { Task {
                await dispatch(NavigationAction {
                    NavigationAction.selectTab(by: AppState.tabTwo)
                    NavigationAction.open(
                        path: ContentView.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                        in: .navigationModel(navigationState.state.observed.navigationModels.first(where: { $0.id == AppState.tabTwo })!)
                    )
                })

            }}) {
                Text("Push \(next) to Tab 2").foregroundColor(.black)
            }

            HStack {
                Button(action: { Task {
                    await dispatch(
                        NavigationAction.open(
                            path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                            in: .new(type: .fullscreen, animate: true)
                        )
                    )
                }}) {
                    Text("Fullscreen \(next)").foregroundColor(.black)
                }

                Button(action: { Task {
                    await dispatch(
                        NavigationAction.open(
                            path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                            in: .new()
                        )
                    )
                }}) {
                    Text("Present \(next)").foregroundColor(.black)
                }
            }
        }
    }

    var thirdSection: some View {
        HStack {
            Button(action: { Task {
                await dispatch(
                    NavigationAction.alert(
                        .init(
                            type: .actionSheet,
                            buttons: [
                                .init(
                                    label: "Close and Present view",
                                    type: .default,
                                    actions: [
                                        NavigationAction.dismiss(.navigationModel(navigationModel)),
                                        NavigationAction.open(
                                            path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                            in: .new()
                                        ),
                                    ]
                                ),
                                .init(
                                    label: "Select tab two",
                                    type: .destructive,
                                    actions: [
                                        NavigationAction.dismiss(.navigationModel(navigationModel)),
                                        NavigationAction.selectTab(by: AppState.tabTwo),
                                    ]
                                ),
                                .init(label: "Cancel", type: .cancel),
                            ]
                        ))
                )
            }}) {
                Text("Present an action sheet").foregroundColor(.black)
            }

            Button(action: { Task {
                await dispatch(
                    NavigationAction.alert(
                        .init(
                            title: "Awesome!",
                            message: "It really works!",
                            buttons: [
                                .init(
                                    label: "Present a view",
                                    type: .default,
                                    action: NavigationAction.open(
                                        path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                                        in: .new()
                                    )
                                ),
                                .init(label: "Cancel", type: .cancel),
                            ]
                        ))
                )
            }}) {
                Text("Present an alert").foregroundColor(.black)
            }
        }
    }

    var fourthSection: some View {
        VStack {
            Button(action: { Task {
                await dispatch(NavigationAction.setBadgeValue(
                    to: "\((Int(navigationState.state.observed.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) - 1)",
                    withModelID: navigationModel.id,
                    withColor: [.red, .blue, .yellow, .purple, .green].randomElement()
                ))
            }}) {
                Text("Decrease badgeValue")
            }
            Button(action: { Task {
                await dispatch(NavigationAction.setBadgeValue(
                    to: "\((Int(navigationState.state.observed.navigationModels.first(where: { $0.id == navigationModel.id })?.tab?.badgeValue ?? "unknown") ?? 0) + 1)",

                    withModelID: navigationModel.id,
                    withColor: [.red, .blue, .yellow, .purple, .green].randomElement()
                ))
            }}) {
                Text("Increase badgeValue")
            }

            Button(action: { Task {
                await dispatch(NavigationAction.setBadgeValue(to: nil, withModelID: navigationModel.id, withColor: nil))
            }}) {
                Text("Reset badge")
            }
        }
    }

    var fithSection: some View {
        VStack {
            Button(action: { Task {
                await dispatch(
                    NavigationAction.open(
                        path: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                        in: .current(animate: false)
                    )
                )
            }}) {
                Text("Push to current, no animation")
            }

            Button(action: { Task {
                guard let currentNavModel = navigationState.state.observed.navigationModels.first(where: { $0.id == navigationState.state.observed.selectedModelId }) else {
                    return
                }
                await dispatch(
                    NavigationAction.replace(
                        path: currentNavModel.selectedPath,
                        with: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(next)"])!,
                        in: currentNavModel
                    )
                )
            }}) {
                Text("Replace current path with new")
            }
        }
    }

    let colors: [Color] = [
        .red, .green, .blue, .yellow, .purple, .pink, .gray, .brown, .white,
    ]
    var sixSection: some View {
        VStack {
            ForEach(colors, id: \.self) { color in
                color.frame(height: 200)
            }

            Button(action: { Task {
                await dispatch(NavigationAction {
                    NavigationAction.selectTab(by: AppState.tabOne)

                    NavigationAction.open(
                        path: ContentView.navigationRoutes.last!.reverse(params: ["name": "\(next)"])!,
                        in: .navigationModel(navigationState.state.observed.navigationModels.first(where: { $0.id == AppState.tabOne })!)
                    )
                })
            }}) {
                Text("Push \(next) to Tab 1").foregroundColor(.black)
            }
        }
    }
}
