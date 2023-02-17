import Foundation
import Logger
import ReduxMonitor
import SwiftReduxRouter
import SwiftUIRedux

extension NavigationActions.SetSelectedPath: Action {}
extension NavigationActions.Dismiss: Action {}
extension NavigationActions.NavigationDismissed: Action {}
extension NavigationActions.Push: Action {}
extension NavigationActions.Present: Action {}
extension NavigationActions.SelectTab: Action {}
extension NavigationActions.SetBadgeValue: Action {}
extension NavigationActions.Replace: Action {}

/// The state of the app
struct AppState: Codable {
    private(set) var navigation: NavigationState

    static let tabOne = UUID()
    static let tabTwo = UUID()

    @MainActor static func createStore(
        initState: AppState
    ) -> Store<AppState> {
        var middlewares = [Middleware<AppState>]()
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
        let store = Store<AppState>(reducer: AppState.reducer, state: initState, middleware: middlewares)

        return store
    }

    @MainActor static func reducer(action: Action, state: AppState) -> AppState {
        return AppState(
            navigation: NavigationState.reducer(action: action, state: state.navigation)
        )
    }
}

extension AppState {
    @MainActor static var initNavigationState: AppState {
        AppState(
            navigation: NavigationState(navigationModels: [
                NavigationModel.createInitModel(
                    id: Self.tabOne,
                    name: "tab1",
                    selectedPath: ContentView.navigationRoutes.first!.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "First Tab",
                        icon: NavigationTab.Icon.system(name: "star.fill")
                    )
                ),
                NavigationModel.createInitModel(
                    id: Self.tabTwo,
                    name: "tab2",
                    selectedPath: ContentView.navigationRoutes.last!.reverse(params: ["name": "\(1)"])!,
                    tab: NavigationTab(
                        name: "Second Tab",
                        icon: NavigationTab.Icon.system(name: "heart.fill"),
                        badgeColor: .red
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
