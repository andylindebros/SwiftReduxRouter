import Foundation
import SwiftReduxRouter
import SwiftUIRedux

public enum ReactiveMiddleware {
    static func createMiddleware() -> Middleware<AppState> {
        return { _, _ in
            { next in
                { action in
                    let nextAction: Void = await next(action)

                    return nextAction
                }
            }
        }
    }
}
