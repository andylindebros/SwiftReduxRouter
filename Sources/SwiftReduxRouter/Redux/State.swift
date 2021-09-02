import Combine
import Foundation
import ReSwift

// MARK: State

public class NavigationState: ObservableObject {
    // MARK: Published vars

    /// Active session. It can only be one sessin at the time
    @Published fileprivate(set) var selectedSessionId = UUID()

    /// Available sessions. Tab sessions are defined here.
    @Published fileprivate(set) var sessions = [NavigationSession]()

    public init(sessions: [NavigationSession]? = nil) {
        if let sessions = sessions {
            self.sessions = sessions
        }
    }
}

// MARK: Reducer

public func navigationReducer(action: Action, state: NavigationState?) -> NavigationState {
    var state = state ?? NavigationState()

    switch action {
    case let a as NavigationActions.SetSelectedPath:
        if let index = state.sessions.firstIndex(where: { $0.id == a.session.id }) {
            state.sessions[index].nextPath = a.session.nextPath
            state.sessions[index].selectedPath = a.session.nextPath

            // Remove all indexes that comes after current path
            if let presentedPathIndex = state.sessions[index].presentedPaths.firstIndex(where: { $0.id == state.sessions[index].selectedPath.id }) {
                let presentedPaths = state.sessions[index].presentedPaths

                state.sessions[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
            }
        }
    case let a as NavigationActions.Dismiss:
        setupPushState(state: &state, path: a.path, target: a.target)
    case let a as NavigationActions.Push:
        setupPushState(state: &state, path: a.path, target: a.target)
    case let a as NavigationActions.SessionDismissed:
        if let index = state.sessions.firstIndex(where: { $0.id == a.session.id }) {
            state.sessions.remove(at: index)
        }
    case let a as NavigationActions.GoBack:
        if let index = state.sessions.firstIndex(where: { $0.name == a.target }) {
            state.sessions[index].nextPath = NavigationPath(a.destination.rawValue)
        }

    default:
        break
    }
    return state
}

private func setupPushState(state: inout NavigationState, path: NavigationPath, target: String) {
    if let index = state.sessions.firstIndex(where: { $0.name == target }) {
        state.sessions[index].nextPath = path
        state.sessions[index].presentedPaths.append(path)
        state.selectedSessionId = state.sessions[index].id

    } else {
        let session = NavigationSession(name: target, path: path, selectedPath: NavigationPath(""))
        state.sessions.append(session)
        state.selectedSessionId = session.id
    }
}
