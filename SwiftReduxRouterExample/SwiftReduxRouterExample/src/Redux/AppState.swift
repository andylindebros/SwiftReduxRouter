import Foundation
import ReSwift
import SwiftReduxRouter

/// The state of the app
struct AppState: StateType {
    private(set) var navigation: NavigationState
}

final class AppStore {
    // MARK: Public

    lazy var initNavigationState: NavigationState = {
        NavigationState(sessions: [
            NavigationSession(
                name: "main",
                path: NavigationPath("root"),
                tab: NavigationTab(
                    name: "first",
                    icon: "whatever"
                )
            ),
            NavigationSession(
                name: "second",
                path: NavigationPath("root"),
                tab: NavigationTab(
                    name: "second",
                    icon: "whatever"
                )
            ),
        ])
    }()

    private(set) lazy var store: Store<AppState> = {
        Store<AppState>(reducer: appReducer, state: AppState(navigation: initNavigationState), middleware: [])
    }()

    static let shared = AppStore()
}
