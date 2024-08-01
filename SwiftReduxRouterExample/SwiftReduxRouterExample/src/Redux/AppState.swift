import Foundation
import Logger
import ReduxMonitor
@preconcurrency import SwiftReduxRouter
import SwiftUIRedux

extension NavigationAction: Action {}

extension Navigation.State: SubState {
    var observedState: any ObservedStruct { observed }
}

extension Navigation.ObservedState: ObservedStruct {
    func isObservedStateEqual(to newValue: any ObservedStruct) -> Bool { (newValue as? Navigation.ObservedState) == self }
}

public struct MainState: Sendable, Codable, SubState {
    var observedState: any ObservedStruct { observed }

    enum Actions: Action {
        case resetScroll
    }

    public init(observed: MainState.Observed = .init()) {
        self.observed = observed
    }

    public var observed: MainState.Observed

    @MainActor static func reducer<Action>(action: Action, state: MainState) -> MainState {
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

public extension MainState {
    struct Observed: Sendable, Equatable, Codable, ObservedStruct {
        public init() {}
        var pathScrollToTop: NavigationPath?
        func isObservedStateEqual(to newValue: any ObservedStruct) -> Bool { (newValue as? MainState.Observed) == self }
    }
}

/// The state of the app
struct AppState: Codable {
    init(main: MainState, navigation: Navigation.State) {
        self.navigation = Observed(initialState: navigation)
        self.main = Observed(initialState: main)
    }

    private(set) var main: Observed<MainState>
    private(set) var navigation: Observed<Navigation.State>

    static let tabOne = UUID()
    static let tabTwo = UUID()

    @MainActor static func createStore(
        initState: AppState
    ) -> Store<AppState> {
        var middlewares = [Middleware<AppState>]()
        middlewares.append(ReactiveMiddleware.createMiddleware())
        #if DEBUG
            middlewares.append { _, _ in
                { next in
                    { action in
                        Task.detached {
                            Logger().publish(
                                message: "⚡️Action:",
                                obj: action,
                                level: .debug
                            )
                        }

                        return next(action)
                    }
                }
            }
            middlewares.append(AppState.createReduxMontitorMiddleware(monitor: ReduxMonitor()))
        #endif
        return Store<AppState>(reducer: AppState.reducer, state: initState, middleware: middlewares)
    }

    @MainActor static func reducer(action: Action, state: AppState) -> AppState {
        state.navigation.setState(Navigation.State.reducer(action: action, state: state.navigation.state))
        state.main.setState(MainState.reducer(action: action, state: state.main.state))
        return state
    }
}

extension AppState {
    private static func createReduxMontitorMiddleware(monitor: ReduxMonitorProvider) -> Middleware<Any> {
        return { _, state in
            var monitor = monitor
            monitor.connect()

            monitor.monitorAction = { monitorAction in
                let decoder = JSONDecoder()
                switch monitorAction.type {
                case let .jumpToState(_, stateDataString):

                    guard
                        let stateData = stateDataString.data(using: .utf8),
                        let newState = try? decoder.decode(AppState.self, from: stateData)
                    else {
                        return
                    }

                    // dispatch(JumpState(navigationState: newState.navigation))

                case .action:
                    break
                }
            }
            return { next in
                { action in
                    let newAction: Void = next(action)
                    let newState = state()
                    if let encodableState = newState as? Encodable {
                        monitor.publish(action: AnyEncodable(action), state: AnyEncodable(encodableState))
                    } else {
                        print("Could not monitor action because either state or action does not conform to encodable", action)
                    }
                    return newAction
                }
            }
        }
    }
}

struct JumpState: NavigationJumpStateAction, Action {
    let navigationState: NavigationState

    var description: String {
        "JumpState"
    }
}

struct Launch: Action, Encodable {}

final class Observed<O: SubState>: ObservableObject, Codable {
    init(initialState: O) {
        state = initialState
    }

    @Published private(set) var observedState: UUID = .init()
    private(set) var state: O

    @discardableResult fileprivate func setState(_ newState: O) -> Self {
        let testState = state.observedState
        state = newState
        if !newState.observedState.isObservedStateEqual(to: testState) {
            observedState = UUID()
        }
        return self
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        state = try values.decode(O.self, forKey: .state)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
    }

    public enum CodingKeys: CodingKey {
        case state
    }
}

protocol ObservedStruct: Sendable, Equatable, Codable {
    func isObservedStateEqual(to: any ObservedStruct) -> Bool
}

protocol SubState: Sendable, Codable {
    var observedState: any ObservedStruct { get }
}
