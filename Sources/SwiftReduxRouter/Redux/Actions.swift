import Foundation

public protocol NavigationJumpStateAction: CustomLogging {
    var navigationState: NavigationState { get }
}

public enum NavigationActions {
    /// Action tha will push the next view. Dispatch this action if you will present or push a view.
    public struct Push: Encodable, CustomLogging {
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

    public struct Dismiss: Encodable, CustomLogging {
        public init(session: NavigationSession) {
            self.session = session
        }

        public var session: NavigationSession

        public var description: String {
            "\(type(of: self)) session '\(session.name)'"
        }
    }

    /// Action that defines what View that are actually displayed
    public struct SetSelectedPath: Encodable, CustomLogging {
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
    public struct SessionDismissed: Encodable, CustomLogging {
        /// The session that should dismiss the view
        public var session: NavigationSession

        public init(session: NavigationSession) {
            self.session = session
        }

        public var description: String {
            "\(type(of: self)) with target: \(session.name)"
        }
    }
}
