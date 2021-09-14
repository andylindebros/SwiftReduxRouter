import Foundation
import Logger
import ReduxMonitor
import ReSwift
import SwiftReduxRouter
/// The state of the app
struct AppState: Codable {
    private(set) var navigation: NavigationState

    static func createStore(
        initState: AppState? = nil
    ) -> Store<AppState> {
        var middlewares = [Middleware<AppState>]()
#if DEBUG
        middlewares.append { _, _ in
            { next in
                { action in
                    DispatchQueue.global(qos: .background).async {
                        Logger.shared.publish(
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
        let store = Store<AppState>(reducer: AppState.reducer, state: initState, middleware: middlewares)

        return store
    }

    static func reducer(action: Action, state: AppState?) -> AppState {
        return AppState(
            navigation: navigationReducer(action: action, state: state?.navigation)
        )
    }

    static var initNavigationState: AppState {
//        AppState(
//            navigation: NavigationState(sessions: [
//                NavigationSession.createInitSession(
//                    name: "tab1",
//                    selectedPath: ContentView.navigationRoute.reverse(params: ["name": "\(1)"])!
//                 ),
//
//            ])
//        )

        AppState(
            navigation: NavigationState(sessions: [
                NavigationSession.createInitSession(
                    name: "tab1",
                    selectedPath: ContentView.navigationRoute.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "First Tab",
                        icon: NavigationTab.Icon.system(name: "star.fill")
                    )
                ),
                NavigationSession.createInitSession(
                    name: "tab2",
                    selectedPath: ContentView.navigationRoute.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "Second Tab",
                        icon: NavigationTab.Icon.system(name: "heart.fill")
                    )
                ),
            ])
        )
    }
}

extension AppState {
    private static func createReduxMontitorMiddleware(monitor: ReduxMonitorProvider) -> Middleware<Any> {
        return { dispatch, state in
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

                    dispatch(JumpState(navigationState: newState.navigation))

                case .action:
                    break
                }
            }
            return { next in
                { action in
                    let newAction: Void = next(action)
                    let newState = state()
                    if let encodableAction = action as? Encodable, let encodableState = newState as? Encodable {
                        monitor.publish(action: AnyEncodable(encodableAction), state: AnyEncodable(encodableState))
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
}

struct Launch: Action, Encodable {}
