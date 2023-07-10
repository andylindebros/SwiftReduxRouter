import Foundation
#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

public protocol NavigationAction: Codable, CustomLogging, Sendable {}

public protocol NavigationJumpStateAction: CustomLogging, Sendable {
    var navigationState: NavigationState { get }
}

public enum NavigationActions {
    public struct UpdateIcon: NavigationAction {
        public init(navigationModelID: UUID, iconName: String) {
            self.navigationModelID = navigationModelID
            self.iconName = iconName
        }

        public var navigationModelID: UUID
        public var iconName: String
    }

    public struct SetBadgeValue: NavigationAction {
        #if canImport(UIKit)
            public init(of navigationModelID: UUID, withValue badgeValue: String?, withColor color: UIColor? = nil) {
                self.navigationModelID = navigationModelID
                self.badgeValue = badgeValue
                self.color = color
            }
        #else
            public init(of navigationModelID: UUID, withValue badgeValue: String?) {
                self.navigationModelID = navigationModelID
                self.badgeValue = badgeValue
            }
        #endif
        public let navigationModelID: UUID
        public let badgeValue: String?
        #if canImport(UIKit)
            public let color: UIColor?
        #endif
    }

    /// Action that will push the next view. Dispatch this action if you will present or push a view.
    public struct Push: NavigationAction {
        /// The path of the route that will be pushed
        public var path: NavigationPath

        /// Define the session that the path will be pushed to.
        public var target: NavigationTarget

        public init(path: NavigationPath, to target: NavigationTarget) {
            self.path = path
            self.target = target
        }

        public var description: String {
            "\(type(of: self)) path '\(path.path ?? "")' to target '\(target)'"
        }
    }

    public struct Present: NavigationAction {
        public var path: NavigationPath

        public init(path: NavigationPath) {
            self.path = path
        }

        public var description: String {
            "\(type(of: self)) path '\(path.path ?? "")'"
        }
    }

    public struct Dismiss: NavigationAction {
        public init(navigationModel: NavigationModel) {
            self.navigationModel = navigationModel
        }

        public var navigationModel: NavigationModel

        public var description: String {
            "\(type(of: self)) session '\(navigationModel.path?.path ?? navigationModel.id.uuidString)'"
        }
    }

    /// Action that defines what View that are actually displayed
    public struct SetSelectedPath: NavigationAction {
        /// The session that is presenting the view
        public var navigationModel: NavigationModel
        public var navigationPath: NavigationPath

        public init(navigationModel: NavigationModel, navigationPath: NavigationPath) {
            self.navigationModel = navigationModel
            self.navigationPath = navigationPath
        }

        public var description: String {
            "\(type(of: self)) \(navigationPath.path ?? "") for target '\(navigationModel.path?.path ?? navigationModel.id.uuidString)'"
        }
    }

    /// Action that dismisses a presented view
    public struct NavigationDismissed: NavigationAction {
        /// The session that should dismiss the view
        public var navigationModel: NavigationModel

        public init(navigationModel: NavigationModel) {
            self.navigationModel = navigationModel
        }

        public var description: String {
            "\(type(of: self)) with target: \(navigationModel.path?.path ?? navigationModel.id.uuidString)"
        }
    }

    public struct SelectTab: NavigationAction {
        public var id: UUID

        public init(by id: UUID) {
            self.id = id
        }

        public var description: String {
            "\(type(of: self)) id: \(id.uuidString)"
        }
    }

    public struct Replace: NavigationAction {
        public let path: SwiftReduxRouter.NavigationPath
        public let newPath: SwiftReduxRouter.NavigationPath
        public let navigationModel: NavigationModel

        public init(path: SwiftReduxRouter.NavigationPath, with newPath: SwiftReduxRouter.NavigationPath, in navigationModel: NavigationModel) {
            self.path = path
            self.newPath = newPath
            self.navigationModel = navigationModel
        }

        public var description: String {
            "\(type(of: self)) path: \(navigationModel.path?.path ?? "")\(path.path ?? "") with \(newPath.path ?? "")"
        }
    }

    public struct Deeplink: Codable, CustomLogging, Sendable {
        public init?(with url: URL?) {
            guard let url = url else { return nil }
            self.url = url
        }

        let url: URL

        public func reaction(of state: NavigationState) -> NavigationAction? {
            if let model = findNavigationModel(in: state) {
                let newURL = URL(string: url.path.replacingOccurrences(of: model.path?.url?.absoluteString ?? "", with: ""))

                // Select: URL has a excat match
                if newURL == model.selectedPath.url || url.path == model.path?.url?.absoluteString {
                    return NavigationActions.SetSelectedPath(navigationModel: model, navigationPath: model.selectedPath)
                }

                if let newURL = newURL {
                    // Found and select already mathing path in model
                    if let foundPath = model.presentedPaths.first(where: { $0.path == newURL.absoluteString }) {
                        return NavigationActions.SetSelectedPath(navigationModel: model, navigationPath: foundPath)
                    }

                    // Present new path to found model
                    return NavigationActions.Push(path: NavigationPath(newURL), to: .navigationModel(model, animate: true))
                }
            } else {
                // Push new path to known navigationModel (found in navigation routes)
                if
                    let pattern = URLMatcher().match(url.path, from: state.navigationModelRoutes.compactMap { $0.path }, ensureComponentsCount: false),
                    let newPath = NavigationPath.create(URL(string: url.path.replacingOccurrences(of: pattern.path, with: "")))
                {
                    return NavigationActions.Push(path: newPath, to: .new(withModelPath: NavigationPath(URL(string: pattern.path)), type: .regular))

                    // push to new navigationModel
                } else if let newPath = NavigationPath.create(URL(string: url.path)) {
                    return NavigationActions.Push(path: newPath, to: .new())
                }
                return nil
            }
            return nil
        }

        private func findNavigationModel(in state: NavigationState) -> NavigationModel? {
            guard
                let pattern = URLMatcher().match(url.path, from: state.navigationModels.compactMap { $0.path?.url?.absoluteString }, ensureComponentsCount: false)?.pattern,
                let navigationModel = state.navigationModels.first(where: { $0.path?.url?.absoluteString == pattern })
            else {
                return nil
            }
            return navigationModel
        }
    }
}
