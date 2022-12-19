import Foundation
import UIKit

public protocol NavigationJumpStateAction: CustomLogging {
    var navigationState: NavigationState { get }
}

public enum NavigationActions {
    public struct UpdateIcon: Codable {
        public init(navigationModelID: UUID, iconName: String) {
            self.navigationModelID = navigationModelID
            self.iconName = iconName
        }

        public var navigationModelID: UUID
        public var iconName: String
    }

    public struct SetBadgeValue: Codable {
        public init(of navigationModelID: UUID, withValue badgeValue: String?, withColor color: UIColor? = nil) {
            self.navigationModelID = navigationModelID
            self.badgeValue = badgeValue
            self.color = color
        }

        public let navigationModelID: UUID
        public let badgeValue: String?
        public let color: UIColor?
    }

    /// Action that will push the next view. Dispatch this action if you will present or push a view.
    public struct Push: Codable, CustomLogging {
        /// The path of the route that will be pushed
        public var path: NavigationPath

        /// Define the session that the path will be pushed to.
        public var target: NavigationTarget

        public init(path: NavigationPath, to target: NavigationTarget) {
            self.path = path
            self.target = target
        }

        public var description: String {
            "\(type(of: self)) path '\(path.path)' to target '\(target)'"
        }
    }

    public struct Present: Codable, CustomLogging {
        public var path: NavigationPath

        public init(path: NavigationPath) {
            self.path = path
        }

        public var description: String {
            "\(type(of: self)) path '\(path.path)'"
        }
    }

    public struct Dismiss: Codable, CustomLogging {
        public init(navigationModel: NavigationModel) {
            self.navigationModel = navigationModel
        }

        public var navigationModel: NavigationModel

        public var description: String {
            "\(type(of: self)) session '\(navigationModel.name)'"
        }
    }

    /// Action that defines what View that are actually displayed
    public struct SetSelectedPath: Codable, CustomLogging {
        /// The session that is presenting the view
        public var navigationModel: NavigationModel
        public var navigationPath: NavigationPath

        public init(navigationModel: NavigationModel, navigationPath: NavigationPath) {
            self.navigationModel = navigationModel
            self.navigationPath = navigationPath
        }

        public var description: String {
            "\(type(of: self)) \(navigationPath.path) for target '\(navigationModel.name)'"
        }
    }

    /// Action that dismisses a presented view
    public struct NavigationDismissed: Codable, CustomLogging {
        /// The session that should dismiss the view
        public var navigationModel: NavigationModel

        public init(navigationModel: NavigationModel) {
            self.navigationModel = navigationModel
        }

        public var description: String {
            "\(type(of: self)) with target: \(navigationModel.name)"
        }
    }

    public struct SelectTab: Codable, CustomLogging {
        public var id: UUID

        public init(by id: UUID) {
            self.id = id
        }

        public var description: String {
            "\(type(of: self)) id: \(id.uuidString)"
        }
    }
}
