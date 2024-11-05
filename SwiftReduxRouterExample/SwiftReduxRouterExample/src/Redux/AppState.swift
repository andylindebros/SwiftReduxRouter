import Foundation
import ReduxMonitor
import SwiftReduxRouter
import SwiftUIRedux

extension NavigationAction: @retroactive DebugInfo {}
extension NavigationAction: @retroactive Action {}
extension Navigation.State: @retroactive SubState {}

struct MainState: Sendable, Codable, SubState {
    enum Actions: Action {
        case resetScroll
    }

    init(observed: MainState.Observed = .init()) {
        self.observed = observed
    }

    struct Observed: Sendable, Equatable, Codable {
        public init() {}
        var pathScrollToTop: NavigationPath?
    }

    var observed: MainState.Observed

    static func reducer<Action>(action: Action, state: MainState) -> MainState {
        var state = state
        switch action as? NavigationAction {
        case let .shouldScrollToTop(path):
            state.observed.pathScrollToTop = path
        default:
            break
        }
        switch action as? MainState.Actions {
        case .resetScroll:
            state.observed.pathScrollToTop = nil
        default:
            break
        }
        return state
    }
}

/// The state of the app
struct AppState: State {
    init(main: MainState, navigation: Navigation.State) {
        self.navigation = Observed(initState: navigation)
        self.main = Observed(initState: main)
    }

    let main: Observed<MainState>
    let navigation: Observed<Navigation.State>

    static let tabOne = UUID()
    static let tabTwo = UUID()

    var observedStates: [any SwiftUIRedux.ObservedProvider] {
        [main, navigation]
    }

    static func createStore(
        initState: AppState
    ) -> Store<AppState> {
        return Store<AppState>(state: initState, middleware: [
            LoggerMiddleware.createMiddleware(),
        ])
    }
}

struct Launch: Action, Encodable {}
