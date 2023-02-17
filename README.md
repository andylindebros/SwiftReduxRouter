# SwiftReduxRouter

SwiftReduxRouter maps navigation to routes that provides SwiftUI views controlled by a Redux NavigationState.

![Demo](https://github.com/andylindebros/SwiftReduxRouter/blob/master/SwiftReduxRouterExample/SwiftReduxRouter.gif)

It is written in for SwiftUI apps based on a Redux pattern. This Router provides a NavigationState and a RouterView written in SwiftUI. The NavigationState controls the navigation and you can easily go back and forth in the action history and the RouterView will navigate to a route.
The routerVIew still uses the UINavigationController in the background since the current SwiftUI NavigationView does not provide necessary methods to make it work.


This package provides a Navigation State, reducer and Actions together with the
`RouterView` written with SwiftUI backed with UIKit.

## Install with Swift Package Manager

```Bash

dependencies: [
    .package(url: "https://github.com/lindebrothers/SwiftReduxRouter.git", .upToNextMajor(from: "10.0.0"))
]
```

## Implementation
In this example we use [ReSwift](https://github.com/ReSwift/ReSwift) but you can integrate `SwiftReduxRouter` with any redux app you want.

1. Add the NavigationState object to your Redux State.

``` Swift
import ReSwift
import SwiftReduxRouter

struct AppState {
    private(set) var navigation: NavigationState

    static func createStore(
        initState: AppState? = nil
    ) -> Store<AppState> {
        var middlewares = [Middleware<AppState>]()

        let store = Store<AppState>(reducer: AppState.reducer, state: initState, middleware: middlewares)

        return store
    }

    static func reducer(action: Action, state: AppState?) -> AppState {
        return AppState(
            navigation: navigationReducer(action: action, state: state?.navigation)
        )
    }
}
```
1. Add the router to your SwftUI View
``` Swift
import SwiftUI
import SwiftReduxRouter

struct ContentView: View {
    @ObservedObject var navigationState: NavigationState

    var dispatch: DispatchFunction

    static let navigationRoutes = [NavigationRoute("hello/<int:name>")]

    var body: some View {
        RouterView(
            navigationState: navigationState,
            routes: [
                RouterView.Route(
                    paths: Self.navigationRoutes,
                    renderView: { navigationModel, params in
                        let presentedName = params["name"] as? Int ?? 0
                        let next = presentedName + 1
                        return AnyView(
                            VStack(spacing: 10) {
                                Text("Presenting \(presentedName)")
                                    .font(.system(size: 50)).bold()
                                    .foregroundColor(.black)
                                Button(action: {
                                    dispatch(
                                        NavigationActions.Push(
                                            path: Self.navigationRoute.reverse(params: ["name": "\(next)"])!,
                                            target: navigationModel.name
                                        ) as! Action
                                    )
                                }) {
                                    Text("Push \(next) to current navigationModel").foregroundColor(.black)
                                }
                            }
                        )
                    }
                )
            ],
            tintColor: .red,
            setSelectedPath: { navigationModel, navigationPath in
                dispatch(NavigationActions.SetSelectedPath(navigationModel: navigationModel, navigationPath: navigationPath))
            },
            onDismiss: { navigationModel in
                dispatch(NavigationActions.NavigationDismissed(navigationModel: navigationModel))
            }
        )
    }
}
                
```
1. Add the ContentView to your app object
``` Swift
import SwiftUI
import ReSwift
@main
struct SwiftReduxRouterExampleApp: App {
    let store: Store<AppState>
    init() {
        store = AppState.createStore(initState: AppState.initNavigationState)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigationState: store.state.navigation, dispatch: store.dispatch)
        }
    }
}
```

1. In AppState.swift, extend NavigationActions so they conform to ReSwift.Action.
``` Swift
import SwiftUIRedux
import SwiftReduxRouter

extension NavigationActions.SetSelectedPath: Action {}
extension NavigationActions.Dismiss: Action {}
extension NavigationActions.NavigationDismissed: Action {}
extension NavigationActions.Push: Action {}
```
1. Add a init navigationState to your store.

```Swift
extension AppState {
    static var initNavigationState: AppState {
        AppState(
            navigation: NavigationState(navigationModels: [
                NavigationModel.createInitModel(
                    name: "tab1",
                    selectedPath: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "First Tab",
                        icon: NavigationTab.Icon.system(name: "star.fill")
                    )
                ),
                NavigationModel.createInitModel(
                    name: "tab2",
                    selectedPath: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "Second Tab",
                        icon: NavigationTab.Icon.system(name: "heart.fill")
                    )
                ),
            ])
        )
    }
}
```

## Render your route with UIViewController

If you need to customize the UIViewController that holds the SwiftUI View you
can use the renderController instead of the render method.

```Swift
class MyController<Content: View>: RouteViewController<Content> {
   func customConfiguration() {
      // make adjustments to your controller
   }
}

RouterView.Route(
 paths: [NavigationRoute("pathtoview")],
 renderController: { _, _ in
    let controller = MyController( root:
       AnyView(
         Text("Awesome!")
       )
     return controller
   }
 },
)
```

## URL Routing.

The router uses URL routing just like a web page. URL routing makes it easy to
organize your project and to work with deep links and Universal links. Choose a
path to your route. Make sure the path is unique, the router maps the first
matching route to a path.

```
mypath/to/a/route
```

You can make parts of the URL dynamic and attach multiple rules

```
user/<string:username>
```

Supported dynamic parameters are:

- string - `user/<strng:username>`
- integer - `user/<int:userId>`
- float - `whatever/<float:someFloat>`
- uuid - `tokens/<uuid:token>`
- path - `somepath/<path:mypath>` will match everything after `somepath/`

## TabBar or a single UINavigationController
If you set the tab property of the NavigatoinModel in the init state, the RouterView will render a UITabBar.

## Presenting views.
if an unrecognized name of a navigationModel is pushed when dispatching `NavigationActions.Push`, the router will present that navigationModel automatically
```Swift
dispatch(NavigationActions.Push(path: NavigationPath("some path to a route"), target: "name of a navigationModel that doesn't exist"))
```
To dismiss it, you simply use the Dismiss action:
``` Swift
dispatch(NavigationActions.Dismiss(navigationModel: The navigationModel to dismiss))
```
You can access the navigationModel object from the renderView method. 
``` Swift
Route(
    ...
    renderView: { navigationModel, params in
        AnyView(
            Text("Awesome")
            .navigationTitle("\(presentedName)")
            .navigationBarItems(trailing: Button(action: {
                dispatch(
                    NavigationActions.Dismiss(navigationModel: navigationModel)
                )
            }) {
                Text(navigationModel.tab == nil ? "Close" : "")
            })
        )
    }
    ...
)
```

### Support for ReduxMonitor
SwiftReduxRouter supports monitoring with [ReduxMonitor](https://github.com/andylindebros/ReduxMonitor). 
Just let your JumpState action conform `NavigationJumpStateAction`
``` Swift
struct JumpState: NavigationJumpStateAction, Action {
    let navigationState: NavigationState
}
```

### Example app.
Try the example app `SwiftReduxRouterExample` to find out more

