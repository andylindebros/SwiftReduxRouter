# SwiftReduxRouting
SwiftReduxRouting maps navigation to routes that provides SwiftUI views. A convenient way of controlling navigation and views. The navigation part is still managed by UIKit since SwiftUI.

It is written with the [ReSwift](https://github.com/ReSwift/ReSwift) Framework that is based on a Redux pattern. But it can be used as standalone feature without any a Redux integration.

This package provides a ReSwift State, reducer and Actions together with the `RouterView` written with SwiftUI and UIKit.

## Install with Swift Package Manager
```Bash
https://github.com/lindebros/SwiftReduxRouting.git
```

## Simple usage
```Swift
import SwiftReduxRouting
import SwiftUI

struct StandAloneView: View {
    var routerView = Router(
        routes: [
            RouterView.Route(
                path: "root",
                render: { _, _, router in
                    AnyView(
                        Button(action: {
                            router?.push(
                                path: NavigationPath("root"),
                                target: "root"
                            )
                        }) {
                            Text("Click me")
                        }
                    )
                }
            )
        ]
    )

    var body: some View {
        routerView
    }
}
```
## Integrated Router with a ReSwift Redux State
If you use ReSwift and Redux you can integrate the NavigationState with your app state.

1. Add the NavigationState object to your ReSwift State.

    ```Swift
    import ReSwift
    import SwiftReduxRouting

    struct AppState: StateType {
      private(set) var navigation: NavigationState
    }
    ```
1. Add a initial navigationState to your store.
    ```Swift
    import ReSwift
    import SwiftReduxRouting

    final class AppStore {
      lazy var initNavigationState: NavigationState = {
        NavigationState(sessions: [
          NavigationSession(
            name: "main",
            path: NavigationPath("start"),
            tab: NavigationTab(
              name: "main",
              icon: "whatever"
            )
          ),
        ])
      }()

      private(set) lazy var store: Store<AppState> = {
          Store<AppState>(reducer: appReducer, state: AppState(navigation: initNavigationState), middleware: [])
      }()
    }
    ```
1. Add the Navigation reducer to your main reducer
    ```Swift
    import ReSwift
    import SwiftReduxRouting


    func appReducer(action: Action, state: AppState?) -> AppState {
          return AppState(
              navigation: navigationReducer(action: action, state: state?.navigation)
          )
      }
    ```
1. Connect the navigation State to your views
    ``` Swift
    import SwiftReduxRouting
    import SwiftUI

    struct ContentView: View {

    var reduxStore: AppStore()

    var body: some View {
        RouterView(
            navigationState: reduxStore.store.state.navigation,
            routes: [
              RouterView.Route(
                path: "pathtoview",
                render: { _, _, _ in
                  AnyView(
                    Button(action: {
                      reduxStore.store.dispatch(
                        NavigationActions.Push(
                          path: NavigationPath("pathtoview"),
                          target: "main"
                        )
                      )
                    }) {
                      Text("Click me")
                    }
                  )
                },
              )
            ],
            tintColor: .red,
            setSelectedPath: { session in
                reduxStore.store.dispatch(NavigationActions.SetSelectedPath(session: session))
            },
            onDismiss: { session in
                reduxStore.store.dispatch(NavigationActions.SessionDismissed(session: session))
            }
        ).edgesIgnoringSafeArea([.top, .bottom])
      }
    }
    ```
    
    ## Render your route with UIViewController
    If you need to customize the UIViewController that holds the SwiftUI View you can use the renderController instead of the render method.
    ```Swift
    class MyController<Content: View>: RouteViewController<Content> {
        override func configureBeforePushed() {
           // make adjustments to your view    
        }
    }
    
    RouterView.Route(
      path: "pathtoview",
      renderController: { _, _, _ in
         let controller = MyController( root:
            AnyView(
              Text("Awesome!")
            )
          controller.configureBeforePushed()
          return controller
        }
      },
    )
    ```

## URL Routing.
The router uses  URL routing just like a web page. URL routing makes it easy to work with deep links and Universal links. 
Choose a path to your view. Make sure the path is unique, otherwise will the user be routed to the first match of the requested path. 

```
mypath/to/a/route
```

You can make parts of the URL dynamic and attach multiple rules to a function
```
user/<string:username>
```
The `render` and `renderController` closures of `Router.Route` will provide the parameters
```Swift
render: { path, parameters, router in
    let username = parameters["username"] as? String
}
```
Supported dynamic parameters are:

- string - `user/<strng:username>`
- integer - `user/<int:userId>`
- float - `whatever/<float:someFloat>` 
- uuid - `tokens/<uuid:token>`
- path - `somepath/<path:mypath>`  will match everything after `somepath/`


