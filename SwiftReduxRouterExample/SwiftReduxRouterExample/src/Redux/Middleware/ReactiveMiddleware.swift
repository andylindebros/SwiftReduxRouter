import Foundation
import SwiftReduxRouter
import SwiftUIRedux

public enum ReactiveMiddleware {
    static func createMiddleware() -> Middleware<AppState> {
        return { dispatch, state in
            { next in
                { action in
                    let nextAction: Void = await next(action)

                    if
                        case let NavigationAction.deeplink(deeplink) = action,
                        let reaction = await deeplink.action(for: state.navigation.state),
                        let navigationAction = reaction as? Action
                    {
                        await dispatch(navigationAction)
                    }

                    return nextAction
                }
            }
        }
    }
}
