import ReSwift
import SwiftUI

/**
 Use Router if you not indend to integrate the navigation state with your store.
 */
public struct Router: View {
    private let store: NavigationStore
    private let routes: [RouterView.Route]

    public init(routes: [RouterView.Route], sessions: [NavigationSession] = []) {
        self.routes = routes

        var sessions = sessions

        if sessions.count == 0 {
            sessions.append(NavigationSession(name: "root", path: NavigationPath("root")))
        }

        store = NavigationStore(sessions: sessions)
    }

    public func push(path: NavigationPath, target: String) {
        store.store.dispatch(NavigationActions.Push(path: path, target: target))
    }

    public func goBack(target: String, destination: NavigationGoBackIdentifier) {
        store.store.dispatch(NavigationActions.GoBack(target: target, destination: destination))
    }

    public func dismiss(target: String) {
        push(path: NavigationPath(RouterView.dismissActionIdentifier), target: target)
    }

    public var body: some View {
        RouterView(
            navigationState: store.store.state.navigation,
            routes: routes,
            tintColor: .red,
            setSelectedPath: { session in
                store.store.dispatch(NavigationActions.SetSelectedPath(session: session))
            },
            onDismiss: { session in
                store.store.dispatch(NavigationActions.SessionDismissed(session: session))
            },
            standaloneRouter: self
        ).edgesIgnoringSafeArea([.top, .bottom])
    }
}

private struct NavigationMainState {
    private(set) var navigation: NavigationState
}

private class NavigationStore {
    let sessions: [NavigationSession]
    init(sessions: [NavigationSession]) {
        self.sessions = sessions
    }

    private(set) lazy var store: Store<NavigationMainState> = {
        Store<NavigationMainState>(reducer: Self.reducer, state: NavigationMainState(navigation: NavigationState(sessions: sessions)), middleware: [])
    }()

    static func reducer(action: Action, state: NavigationMainState?) -> NavigationMainState {
        return NavigationMainState(
            navigation: navigationReducer(action: action, state: state?.navigation)
        )
    }
}
