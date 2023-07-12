import Foundation

@MainActor public class MVVMWrapper {
    public init(state: NavigationState) {
        self.state = state
    }

    private(set) var state: NavigationState

    public func dispatch(_ action: NavigationAction) {
        state = NavigationState.reducer(action: action, state: state)
    }
}
