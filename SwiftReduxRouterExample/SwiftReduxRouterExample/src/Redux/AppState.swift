import Foundation
import ReSwift
import SwiftReduxRouter

/// The state of the app
struct AppState {
    private(set) var navigation: NavigationState
}

final class AppStore {
    // MARK: Public

    lazy var initNavigationState: NavigationState = {
        NavigationState(sessions: [
            NavigationSession(
                name: "tab1",
                path: AppRoutes.helloWorld.navigationRoute.reverse(params: ["name": AppRoutes.names.first!])!,
                tab: NavigationTab(
                    name: "First Tab",
                    icon: NavigationTab.Icon.system(name: "star.fill")
                )
            ),
            NavigationSession(
                name: "tab2",
                path: AppRoutes.viewControllerRoute.navigationRoute.reverse()!,
                tab: NavigationTab(
                    name: "Second Tab",
                    icon: NavigationTab.Icon.system(name: "heart.fill")
                )
            ),
        ])
    }()

    private(set) lazy var store: Store<AppState> = {
        Store<AppState>(reducer: appReducer, state: AppState(navigation: initNavigationState), middleware: [
            loggerMiddleware
        ])
    }()

    static let shared = AppStore()
}

let loggerMiddleware: Middleware<Any> = { _, _ in
    { next in
        { action in
            DispatchQueue.global(qos: .background).async {
                print(
                    "⚡️Action:",
                    action
                )
            }

            return next(action)
        }
    }
}
