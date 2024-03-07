import Foundation
import SwiftReduxRouter
import SwiftUIRedux

public enum ReactiveMiddleware {
    static func createMiddleware() -> Middleware<AppState> {
        return { _, state in
            { next in
                { action in
                    let nextAction: Void = next(action)

                    guard let state = state() else {
                        return nextAction
                    }

                    if
                        case let NavigationAction.deeplink(deeplink) = action,
                        let reaction = deeplink.action(for: state.navigation),
                        let navigationAction = reaction as? Action
                    {
                        dispatch(navigationAction)
                    }

                    return nextAction
                }
            }
        }
    }
}
