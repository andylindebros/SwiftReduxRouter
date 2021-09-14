import Combine
import Foundation
import ReSwift

// MARK: State

public class NavigationState: ObservableObject, Codable {
    // MARK: Published vars

    /// Active session. It can only be one sessin at the time
    @Published fileprivate(set) var selectedSessionId = UUID()

    /// Available sessions. Tab sessions are defined here.
    @Published fileprivate(set) var sessions = [NavigationSession]()

    var hasPresentedSessions: Bool {
        sessions.first(where: { $0.isPresented }) != nil
    }

    public init(sessions: [NavigationSession]? = nil) {
        if let sessions = sessions {
            self.sessions = sessions

            if let first = sessions.first {
                selectedSessionId = first.id
            }
        }
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedSessionId = try values.decode(UUID.self, forKey: .selectedSessionId)
        sessions = try values.decode([NavigationSession].self, forKey: .sessions)
    }

    enum CodingKeys: CodingKey {
        case selectedSessionId, sessions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(selectedSessionId, forKey: .selectedSessionId)
    }
}

// MARK: Reducer

public func navigationReducer(action: Action, state: NavigationState?) -> NavigationState {
    let state = state ?? NavigationState()

    switch action {
    case let a as NavigationJumpStateAction:
        state.sessions = a.navigationState.sessions
        state.selectedSessionId = a.navigationState.selectedSessionId

    case let a as NavigationActions.SetSelectedPath:
        if let index = state.sessions.firstIndex(where: { $0.id == a.session.id }) {
            state.sessions[index].selectedPath = a.navigationPath
            state.selectedSessionId = state.sessions[index].id

            // Remove all indexes that comes after current path
            if let presentedPathIndex = state.sessions[index].presentedPaths.firstIndex(where: { $0.id == state.sessions[index].selectedPath.id }) {
                let presentedPaths = state.sessions[index].presentedPaths

                state.sessions[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
            }
        }

    case let a as NavigationActions.Dismiss:
        if let index = state.sessions.firstIndex(where: { $0.isPresented && $0.id == a.session.id }) {
            state.sessions.remove(at: index)
        }

    case let a as NavigationActions.Push:
        if let index = state.sessions.firstIndex(where: { $0.name == a.target }) {
            state.selectedSessionId = state.sessions[index].id

        } else {
            let session = NavigationSession(name: a.target, selectedPath: NavigationPath(""))
            state.sessions.append(session)
            state.selectedSessionId = session.id
        }

        if let index = state.sessions.firstIndex(where: { $0.id == state.selectedSessionId }) {
            // Remove all indexes that comes after current path
            if let presentedPathIndex = state.sessions[index].presentedPaths.firstIndex(where: { $0.id == state.sessions[index].selectedPath.id }) {
                let presentedPaths = state.sessions[index].presentedPaths

                state.sessions[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
            }

            state.sessions[index].selectedPath = a.path
            state.sessions[index].presentedPaths.append(a.path)
            state.selectedSessionId = state.sessions[index].id
        }

    case let a as NavigationActions.SessionDismissed:
        if let index = state.sessions.firstIndex(where: { $0.tab == nil && $0.id == a.session.id }) {
            state.sessions.remove(at: index)
        }

    default:
        break
    }
    return state
}
