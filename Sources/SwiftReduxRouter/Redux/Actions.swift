import Foundation
import ReSwift

public protocol NavigationJumpStateAction: Action, CustomLogging {
    var navigationState: NavigationState { get }
}

public enum NavigationActions {
    public struct SessionHasApplicant: Action, Encodable, CustomLogging {
        public init(session: NavigationSession, path: NavigationPath) {
            self.session = session
            self.path = path
        }

        public var session: NavigationSession
        public var path: NavigationPath
    }

    /// Action tha will push the next view. Dispatch this action if you will present or push a view.
    public struct Push: Action, Encodable, CustomLogging {
        /// The path of the route that will be pushed
        public var path: NavigationPath

        /// Define the session that the path will be pushed to.
        public var target: String

        public init(path: NavigationPath, target: String) {
            self.path = path
            self.target = target
        }

        public var description: String {
            "\(type(of: self)) path '\(path.path)' to target '\(target)'"
        }
    }

    public struct Dismiss: Action, Encodable, CustomLogging {
        public init(session: NavigationSession) {
            self.session = session
        }

        public var session: NavigationSession

        public var description: String {
            "\(type(of: self)) session '\(session.name)'"
        }
    }

    /// Action that defines what View that are actually displayed
    public struct SetSelectedPath: Action, Encodable, CustomLogging {
        /// The session that is presenting the view
        public var session: NavigationSession
        public var navigationPath: NavigationPath

        public init(session: NavigationSession, navigationPath: NavigationPath) {
            self.session = session
            self.navigationPath = navigationPath
        }

        public var description: String {
            "\(type(of: self)) \(navigationPath.path) for target '\(session.name)'"
        }
    }

    /// Action that dismisses a presented view
    public struct SessionDismissed: Action, Encodable, CustomLogging {
        /// The session that should dismiss the view
        public var session: NavigationSession

        public init(session: NavigationSession) {
            self.session = session
        }

        public var description: String {
            "\(type(of: self)) with target: \(session.name)"
        }
    }

    /// Action that will push a navigation backwards
    public struct GoBack: Action, Encodable, CustomLogging {
        /// The session that should go backwards
        public var target: String

        /// Go to the beginning och one step back
        public var destination: NavigationGoBackIdentifier

        public init(target: String, destination: NavigationGoBackIdentifier) {
            self.target = target
            self.destination = destination
        }
    }
}
