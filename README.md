# SwiftReduxRouter

SwiftReduxRouter maps navigation to routes that provides SwiftUI views controlled by a Redux NavigationState.

![Demo](https://github.com/andylindebros/SwiftReduxRouter/blob/master/SwiftReduxRouterExample/SwiftReduxRouter.gif)

It is written for SwiftUI apps based on a Redux pattern. This Router provides a NavigationState and a RouterView backed with UIKit. The NavigationState controls the navigation and you can easily go back and forth in the action history and the RouterView will navigate to a route.
The routerView uses the UINavigationController in the background since the current SwiftUI NavigationView does not provide necessary methods to make it work.

This package also provides a nessecary actions to use to changed the navigation state.

## Works with:

- SwiftUIRedux: https://github.com/andylindebros/SwiftUIRedux

## Install with Swift Package Manager

```Bash

dependencies: [
    .package(url: "https://github.com/lindebrothers/SwiftReduxRouter.git", .upToNextMajor(from: "<Desired version>"))
]
```

## Implementation
See examples how to implement in the Example project within this package.

#### Deeplinks
Setup your scheme and deep links will be opened by the router.

Following rules apply to the example implementation above:

- `swiftreduxrouter://example.com/tab1/page/2` will be pushed to the first tab
- `swiftreduxrouter://example.com/tab1/page/1` will be selected in the first tab
- `swiftreduxrouter:///tab2/page/2` will be selected in and will select the second tab. 
- `swiftreduxrouter:///tab2/page/1` will be pushed to the second tab
- `swiftreduxrouter:///standalone/page/1` will be presented in the standalone navigationController on top of the tab bar
- `swiftreduxrouter:///standalone/page/2` will be pushed to the presented standalone navigationController
- `swiftreduxrouter:///page/1` will be presented in a new navigationController on top of the tab bar
- `swiftreduxrouter:///tab1` will select the first tab

You can dispatch the Deeplink anywhere in your app to navigate to any desired route.
```Swift
Button(action: {
    store.disptach(Deeplink(url: URL(string: "/tab2/page/2")).action(for: store.navigation))
}) {
    Text("Take me to page two in the second tab")
}
```

Test deeplinks from the terminal:
```Bash
xcrun simctl openurl booted '<INSERT_URL_HERE>'
```


## URL Routing.

The router uses URL routing just like a web page. URL routing makes it easy to
organize your project and to work with deep links and Universal links. Choose a
path to your route. Make sure the path is unique, the router maps the first
matching route to a path.

```
/mypath/to/a/route
```

You can make parts of the URL dynamic and attach multiple rules

```
/user/<string:username>
```

Supported dynamic parameters are:

- string - `user/<strng:username>`
- integer - `user/<int:userId>`
- float - `whatever/<float:someFloat>`
- uuid - `tokens/<uuid:token>`
- path - `somepath/<path:mypath>` will match everything after `somepath/`

## TabBar or a single UINavigationController
If you set the tab property of the NavigationModel in the init state, the RouterView will render a UITabBar.

## Presenting views.
A view gets presented by setting the navigationTarget to NavigationTarget.new(). 
```Swift
dispatch(NavigationAction.add(path: NavigationPath("some path to a route"), to: .new()))
```
To dismiss it, you simply use the Dismiss action:
``` Swift
dispatch(NavigationAction.Dismiss(navigationModel: The navigationModel to dismiss))
```
You can access the navigationModel object from the renderView method. 
``` Swift
Route(
    ...
    render: { navigationModel, params in
        RouteViewController(rootView:
            Text("Awesome")
            .navigationTitle("\(presentedName)")
            .navigationBarItems(trailing: Button(action: {
                dispatch(
                    NavigationAction.dismiss(navigationModel)
                )
            }) {
                Text(navigationModel.tab == nil ? "Close" : "")
            })
        )
    }
    ...
)
```

### Alerts
You can trigger alerts by dispatching `NavigationAction.alert`
```Swift
    dispatch(
        Navigation.alert(AlertModel(
           type: .alert // .alert || .actionSheet, default is .alert
           label: "The label of the alert", // Optional
           message: "Optional message", // Optional
           buttons: [
              AlertModelButton(
                 label: "the button label",
                 action: SomeAction // needs to conform to NavigationActionProvider
                 type: UIAlertAction.Style = .default
              )
           ]
        ))
    )
    
    extension SomeAction: NavigationActionsProvider {}
```

## Support for ReduxMonitor
SwiftReduxRouter supports monitoring with [ReduxMonitor](https://github.com/andylindebros/ReduxMonitor). 
Just let your JumpState action conform `NavigationJumpStateAction`
``` Swift
struct JumpState: NavigationJumpStateAction, Action {
    let navigationState: NavigationState
}
```

### Example app.
Try the example app `SwiftReduxRouterExample` to find out more

## Links

- SwiftUIRedux: https://github.com/andylindebros/SwiftUIRedux
