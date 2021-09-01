import Foundation
import ReSwift

public enum NavigationActions {
    /// Action tha will push the next view. Dispatch this action if you will present or push a view.
    public struct Push: Action {
        /// The path of the route that will be pushed
        public var path: NavigationPath

        /// Define the session that the path will be pushed to.
        public var target: String

        public init(path: NavigationPath, target: String) {
            self.path = path
            self.target = target
        }
    }

    public struct Dismiss: Action {
        public var path: NavigationPath
        public var target: String
        public init(target: String) {
            path = NavigationPath(RouterView.dismissActionIdentifier)
            self.target = target
        }
    }

    /// Action that defines what View that are actually displayed
    public struct SetSelectedPath: Action {
        /// The session that is presenting the view
        public var session: NavigationSession

        public init(session: NavigationSession) {
            self.session = session
        }
    }

    /// Action that dismisses a presented view
    public struct SessionDismissed: Action {
        /// The session that should dismiss the view
        public var session: NavigationSession

        public init(session: NavigationSession) {
            self.session = session
        }
    }

    /// Action that will push a navigation backwards
    public struct GoBack: Action {
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
