import ReSwift
import SwiftReduxRouter


func appReducer(action: Action, state: AppState?) -> AppState {
    return AppState(
        navigation: navigationReducer(action: action, state: state?.navigation)
    )
}
