import Foundation
import SwiftReduxRouter
import SwiftUIRedux

public enum ReactiveMiddleware {
    static func createMiddleware() -> Middleware<AppState> {
        return { dispatch, state in
            { next in
                { action in
                    let nextAction: Void = next(action)

                    guard let state = state() else {
                        return nextAction
                    }

                    switch action {
                    case let a as NavigationActions.Deeplink:
                        if
                            let reaction = a.reaction(of: state.navigation),
                            let navigationAction = reaction as? Action
                        {
                            dispatch(navigationAction)
                        }

                    default:
                        break
                    }

                    return nextAction
                }
            }
        }
    }
}
