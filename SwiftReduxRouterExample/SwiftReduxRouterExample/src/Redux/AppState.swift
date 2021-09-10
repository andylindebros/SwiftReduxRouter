import Foundation
import ReduxMonitor
import ReSwift
import SwiftReduxRouter

/// The state of the app
struct AppState: Codable {
    private(set) var navigation: NavigationState
}

struct JumpState: NavigationJumpStateAction, Action {
    let navigationState: NavigationState
}

struct Launch: Action, Encodable {
    
}

final class AppStore {
    // MARK: Public

    lazy var initNavigationState: NavigationState = {
        NavigationState(sessions: [
            NavigationSession(
                name: "tab1",
                path: AppRoutes.helloWorld.navigationRoute.reverse(params: ["name": "\(1)"])!,
                tab: NavigationTab(
                    name: "First Tab",
                    icon: NavigationTab.Icon.system(name: "star.fill")
                )
            ),
            NavigationSession(
                name: "tab2",
                path: AppRoutes.viewControllerRoute.navigationRoute.reverse(params: ["name": "\(1)"])!,
                tab: NavigationTab(
                    name: "Second Tab",
                    icon: NavigationTab.Icon.system(name: "heart.fill")
                )
            ),
        ])
    }()

    private(set) lazy var store: Store<AppState> = {
        let store = Store<AppState>(reducer: appReducer, state: AppState(navigation: initNavigationState), middleware: [
            loggerMiddleware,
            AppState.createReduxMontitorMiddleware(monitor: ReduxMonitor()),
        ])
        
        store.dispatch(Launch())
        
        return store
    }()

    static let shared = AppStore()
}

private extension AppState {
    static func createReduxMontitorMiddleware(monitor: ReduxMonitorProvider) -> Middleware<Any> {
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

                default:
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
