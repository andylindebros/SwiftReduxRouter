import Foundation
#if os(iOS)
    import UIKit
#endif
import SwiftUICore

public extension Navigation {
    /**
     Specifies how to dismiss a view
     */
    enum DismissTarget: Equatable, Codable, Sendable {
        /**
         Dismisses current selected navigationModel

         - parameter animated:Indicates whether the dismissal should be animated.
         - parameter completion: closure to trigger when dismissal has completed
          */
        case currentModel(animated: Bool = true, withCompletion: CodableClosure? = nil)

        /**
         Dismisses a specific navigationModel

         - parameter model: Desired navigationModel to dismiss
         - parameter animated:Indicates whether the dismissal should be animated.
         - parameter completion: closure to trigger when dismissal has completed
          */
        case model(Model, animated: Bool = true, withCompletion: CodableClosure? = nil)

        /**
          Dismisses a specified navigationPath.

          If the path is part of a navigation stack, it will be removed from the stack.
          If it is the only path in the stack and the model is presented, the entire model will be dismissed.
          -
         - parameter path: Desired navigationPath to dismiss
         - parameter animated:Indicates whether the dismissal should be animated.
         - parameter completion: closure to trigger when dismissal has completed
          */
        case path(Navigation.Path, animated: Bool = true, withCompletion: CodableClosure? = nil)

        /**
         Dismisses all presented navigationModels

         - parameter includingUntracked: also dismiss untracked views
         - parameter completion: closure to trigger when dismissal has completed
          */
        case allPresented(includingUntracked: Bool = true, withCompletion: CodableClosure? = nil)
    }

    /**
     Specifies where and how a path should be presented.
     */
    enum Target: Equatable, Codable, Sendable {
        /**
         Defines a new presentation target.

         - parameter routes: Supported deep link routes.
         - parameter type: The presentation strategy.
         */
        case new(routes: [Route]? = nil, type: PresentationType = .pageSheet())

        /**
         Specifies an existing navigation stack to which the view should be added.

         - parameter mode: Defines the target navigation stack.
         - parameter animate: Indicates whether the presentation should be animated
         */
        case model(Model, animate: Bool = true)

        /**
         Specifies current selected navigation stack to which the view should be added.

         - parameter animate: Indicates whether the presentation should be animated
         */
        case current(animate: Bool = true)
    }
}

public extension Navigation {
    enum TransitionStyle: Equatable, Codable, Sendable {
        case coverVertical
        case flipHorizontal
        case crossDissolve
        case partialCurl

        #if os(iOS)
            var transistionStyle: UIModalTransitionStyle {
                switch self {
                case .coverVertical:
                    return .coverVertical
                case .flipHorizontal:
                    return .flipHorizontal
                case .crossDissolve:
                    return .crossDissolve
                case .partialCurl:
                    return .partialCurl
                }
            }
        #endif
    }
}

public extension Navigation {
    /**
     Defines how the `UINavigationController` should be presented
     */
    enum PresentationType: Equatable, Codable, Sendable {
        /**
         A regular modal presentation

         - parameter options: Modal options
          */
        case pageSheet(options: TransitionOptions = .init())

        /**
         The presented view takes up the entire screen. The underlying (presenting) view is removed from the view hierarchy while the modal view is visible.

         - parameter options: Modal options
          */
        case fullscreen(options: TransitionOptions = .init())

        /**
         The presented view also takes up the entire screen, but unlike fullScreen, the presenting view remains in the view hierarchy, behind the modal view.

          - parameter options: Modal options
          */
        case overFullScreen(options: TransitionOptions = .init())

        /**
         Presents the modal with detents

         - parameter detentsOptions: Detents options
         - parameter options: Modal options
          */
        case detents(DetentOptionsModel, options: TransitionOptions = .init())

        /**
         The modal view appears as a smaller, centered rectangle over the parent view
         - parameter options: Modal options
         */
        case formSheet(options: TransitionOptions = .init())
        #if os(iOS)
        var style: UIModalPresentationStyle {
            switch self {
            case .pageSheet, .detents:
                .pageSheet
            case .fullscreen:
                .fullScreen
            case .overFullScreen:
                .overFullScreen
            case .formSheet:
                .formSheet
            }
        }
        #endif

        var options: TransitionOptions {
            switch self {
            case
                let .pageSheet(options),
                let .fullscreen(options),
                let .overFullScreen(options),
                let .formSheet(options),
                let .detents(_, options):
                options
            }
        }

        var detentItems: [Detent]? {
            switch self {
            case let .detents(model, _):
                model.detents
            default:
                nil
            }
        }

        var selectedDetent: Detent? {
            switch self {
            case let .detents(model, _):
                model.selected
            default:
                nil
            }
        }
    }
}

public extension Navigation.PresentationType {
    /**
     Presents the modal with detents

      - parameter detents: A list of detents that should be available in the modal
      - parameter selected: The selected detent
      - parameter largestUndimmedDetentIdentifier: Largest detents that allows interaction behind the presented modal.
      - parameter prefersGrabberVisible: Show the grabber or not
      - parameter preferredCornerRadius: size of rounded corners of the presented view
      - parameter prefersScrollingExpandsWhenScrolledToEdge: Allows to expand the view when scrolled to the edge
      */
    struct DetentOptionsModel: Equatable, Codable, Sendable {
        public init(detents: [Navigation.PresentationType.Detent], selected: Navigation.PresentationType.Detent? = nil, largestUndimmedDetentIdentifier: Navigation.PresentationType.Detent? = nil, prefersGrabberVisible: Bool = false, preferredCornerRadius: Double? = nil, prefersScrollingExpandsWhenScrolledToEdge: Bool = true) {
            self.detents = detents
            self.selected = selected
            self.largestUndimmedDetentIdentifier = largestUndimmedDetentIdentifier
            self.prefersGrabberVisible = prefersGrabberVisible
            self.preferredCornerRadius = preferredCornerRadius
            self.prefersScrollingExpandsWhenScrolledToEdge = prefersScrollingExpandsWhenScrolledToEdge
        }

        var detents: [Detent]
        var selected: Detent?
        let largestUndimmedDetentIdentifier: Detent?
        let prefersGrabberVisible: Bool
        let preferredCornerRadius: Double?
        let prefersScrollingExpandsWhenScrolledToEdge: Bool
    }

    struct TransitionOptions: Equatable, Codable, Sendable {
        public init(animated: Bool = true, preventDismissal: Bool = false, transistionStyle: Navigation.TransitionStyle = .coverVertical) {
            self.animated = animated
            self.preventDismissal = preventDismissal
            self.transistionStyle = transistionStyle
        }

        var animated: Bool = true
        var preventDismissal: Bool = false
        var transistionStyle: Navigation.TransitionStyle = .coverVertical
    }

    /**
     Supported detents
     */
    enum Detent: Equatable, Codable, Sendable {
        /**
         Native medium size
         */
        case medium

        /**
         Native large size
         */
        case large

        /**
         Custom size of the presented view.

          - parameter identifier: The identifier of the custom size
          - parameter height: the height of the custom size.
          */
        case custom(identifier: String, height: Double)

        var identifier: String {
            switch self {
            case .medium:
                return "medium"
            case .large:
                return "large"
            case let .custom(identifier, _):
                return identifier
            }
        }
        #if os(iOS)
        @MainActor public var detent: UISheetPresentationController.Detent {
            switch self {
            case .medium:
                return .medium()
            case .large:
                return .large()
            case let .custom(identifier, height):
                let identifier = UISheetPresentationController.Detent.Identifier(identifier)
                return .custom(identifier: identifier) { _ in
                    height
                }
            }
        }
        #endif
    }
}

public extension Navigation {
    /**
     Defines a rule for matching a path with a navigationRoute
     */
    enum Rule: Equatable, Codable, Sendable {
        /**
         Allows any params
          */
        case any

        /**
         The value needs to match one of given values in the list

          - parameter matchValue: a list of valid values
          */
        case oneOf([URLPathMatchValue])

        func match(value: URLPathMatchValue) -> Bool {
            switch self {
            case .any:
                true
            case let .oneOf(values):
                values.contains(value)
            }
        }
    }
}

public extension Navigation {
    /**
     Defines a route and includes:

     -   The structure of the URL associated with the route.
     -   Required path values to present the corresponding view.
     -   The minimum `accessLevel` required to access the view.

     - parameter pattern: The url definition of the route
     - parameter name: A name representation of the route
     - parameter rules: A list of rules for the paramterers in the url definition
     - parameter accessLevel: The minimum accessLevel required to access the view
     - parameter nestedPaths: Dependent paths of routes that together defines the route.
     - parameter preExecutionDeeplinkOpenAction: Apply additional action before a path is added to the state.
     */
    struct Route: Equatable, Codable, Sendable, CustomStringConvertible {
        public init(_ pattern: String, name: String? = nil, rules: [String: Rule] = [:], accessLevel: RouteAccessLevel = .private, nestedPaths: [String] = [], preExecutionDeeplinkOpenAction: Action? = nil) {
            self.pattern = pattern
            self.name = name
            self.rules = rules
            self.accessLevel = accessLevel
            self.nestedPaths = nestedPaths.count > 0 ? nestedPaths : [pattern]
            self.preExecutionDeeplinkOpenAction = preExecutionDeeplinkOpenAction
        }

        public let pattern: String
        public let name: String?
        public let rules: [String: Rule]
        public let accessLevel: RouteAccessLevel
        public let nestedPaths: [String]
        public let preExecutionDeeplinkOpenAction: Action?

        public func reverse(params: [String: URLPathMatchValue] = [:], navBarOptions: Path.NavBarOptions? = nil) -> Path? {
            let urlMatcher = URLMatcher()
            let components = urlMatcher.pathComponents(from: pattern)
            var parameters: [String] = []
            for component in components {
                switch component {
                case .plain:
                    parameters.append(component.value)
                case .placeholder:
                    guard let value = params[component.value], let strValue = value.asString else {
                        return nil
                    }

                    if let rule = rules[component.value], !rule.match(value: value) {
                        return nil
                    }

                    parameters.append(strValue)
                }
            }
            var str = parameters.joined(separator: "/")

            if str.prefix(1) != "/" {
                str = "/" + str
            }
            guard let url = URL(string: str) else { return nil }
            return .init(url, name, navBarOptions: navBarOptions)
        }

        func validate(result: URLMatchResult, forAccessLevel candidate: RouteAccessLevel) -> Bool {
            guard
                result.pattern == pattern,
                accessLevel.grantAccess(for: candidate)
            else {
                return false
            }

            for rule in rules {
                guard
                    let value = result.values[rule.key],
                    rule.value.match(value: value)
                else {
                    return false
                }
            }
            return true
        }

        public var description: String {
            "\(type(of: self))(\(pattern))"
        }

        public func append(_ child: Route) -> Route {
            let pattern = pattern + child.pattern
            var rules = rules
            rules.merge(child.rules) { _, new in new }
            var nestedPaths = nestedPaths
            nestedPaths.append(child.pattern)
            return Route(pattern, name: name, rules: rules, accessLevel: accessLevel, nestedPaths: nestedPaths, preExecutionDeeplinkOpenAction: preExecutionDeeplinkOpenAction)
        }

        public func with(access: RouteAccessLevel) -> Route {
            Route(pattern, name: name, rules: rules, accessLevel: access, nestedPaths: nestedPaths, preExecutionDeeplinkOpenAction: preExecutionDeeplinkOpenAction)
        }

        public func withPreExecutionDeeplinkOpenAction(_ action: Action) -> Route {
            Route(pattern, name: name, rules: rules, accessLevel: accessLevel, nestedPaths: nestedPaths, preExecutionDeeplinkOpenAction: action)
        }

        var parentPath: String {
            if nestedPaths.count - 1 > 0 {
                return nestedPaths.prefix(nestedPaths.count - 1).joined()
            }
            return ""
        }
    }
}

public extension Navigation {
    enum RouteAccessLevel: Equatable, Codable, Sendable {
        case `private`
        case `internal`
        case `public`

        func grantAccess(for candidate: RouteAccessLevel) -> Bool {
            switch candidate {
            case .private:
                true
            case .internal:
                self == .public || self == .internal
            case .public:
                self == .public
            }
        }
    }
}

public extension Navigation {
    /**
     Represents a `UIViewController` that is added to the navigation stack. This model is also used to match a URL to a specific route.

     To create a path, use the static create function. The init function is internally protected.
     */
    struct Path: Identifiable, Equatable, Codable, Sendable, CustomStringConvertible {
        public var id: UUID
        public var url: URL?
        public var matchResult: URLMatchResult?
        public var name: String?
        var hasBeenShown: Bool = false
        public let navBarOptions: NavBarOptions?

        init(id: UUID = UUID(), _ url: URL? = nil, _ name: String? = nil, _ matchResult: URLMatchResult? = nil, hasBeenShown: Bool = false, navBarOptions: NavBarOptions? = nil) {
            self.id = id
            self.url = url
            self.name = name
            self.matchResult = matchResult
            self.hasBeenShown = hasBeenShown
            self.navBarOptions = navBarOptions
        }

        public var params: [String: URLPathMatchValue]? {
            matchResult?.values
        }

        public var path: String? {
            url?.path
        }

        /**
         Creates an instance of Path

         - parameter urlString: The string representation of a URL used to identify the route.
         - parameter name: The readable name of the path.
         - parameter navBarOptions: The desired navigation bar options to configure for navBar of the UIViewController.
         */
        public static func create(_ urlString: String, name: String? = nil, navBarOptions: NavBarOptions? = nil) -> Path? {
            guard let url = URL(string: urlString) else { return nil }
            return .init(url, name, navBarOptions: navBarOptions)
        }

        /**
         Creates an instance of Path

         - parameter url: The URL used to identify the route.
         - parameter name: The readable name of the path.
         - parameter navBarOptions: The desired navigation bar options to configure for navBar of the UIViewController.
         */
        public static func create(_ url: URL?, name: String? = nil, navBarOptions: NavBarOptions? = nil) -> Path? {
            guard let url = url else { return nil }
            return .init(url, name, navBarOptions: navBarOptions)
        }

        public var description: String {
            "\(type(of: self))(\(url?.path ?? "unknown"))"
        }

        func urlMatchResult(of availableRoutes: [Route]) -> URLMatchResult? {
            if let url = url {
                URLMatcher().match(url.path, from: availableRoutes.map { $0.pattern })
            } else {
                nil
            }
        }

        func setMatchResultIfNeeded(to newValue: URLMatchResult?) -> Self {
            guard matchResult == nil, let newValue else {
                return self
            }
            return Self(id: id, url, name, newValue, hasBeenShown: hasBeenShown)
        }
    }
}

public extension Navigation.Path {
    /**
     Provides options for the nav bar

     - parameter hideNavigationBar: Defines if the nav bar should be hidden for a viewController
     - parameter title: The title of the viewController
     */
    struct NavBarOptions: Equatable, Codable, Sendable {
        public init(hideNavigationBar: Bool, title: String? = nil) {
            self.hideNavigationBar = hideNavigationBar
            self.title = title
        }

        let hideNavigationBar: Bool
        let title: String?
    }
}

public extension Navigation {
    /**
     Defines a tabBarItem

     - parameter name: The name to be displayed in the tabBar
     - parameter icon: The unselected icon to be displayed in the tabBar
     - parameter selectedIcon: The selected icon to be displayed in the tabBar
     - parameter badgeValue: The value of a badge displayed next to the icon
     - parameter badgeColor: The badge color
     - parameter tipIdentifier: A tip identifier allows tabBarController to show a tip.
     */
    struct Tab: Codable, Sendable, CustomStringConvertible {
        public var name: String
        public var icon: Icon
        public var selectedIcon: Icon?

        public var badgeColor: Color?
        public var badgeValue: String?
        public var tipIdentifier: String?

        public init(name: String, icon: Icon, selectedIcon: Icon? = nil, badgeValue: String? = nil, badgeColor: Color? = nil, tipIdentifier: String? = nil) {
            self.name = name
            self.icon = icon
            self.selectedIcon = selectedIcon
            self.badgeValue = badgeValue
            self.badgeColor = badgeColor
            self.tipIdentifier = tipIdentifier
        }

        public var description: String {
            "\(type(of: self))(\(name))"
        }
    }
}

public extension Navigation.Tab {
    #if os(iOS)
    struct IconImage: Identifiable, Sendable {
        public init(id: String, image: UIImage) {
            self.id = id
            self.image = image
        }

        public let id: String
        public let image: UIImage?
    }
    #endif

    enum Icon: Codable, Sendable {
        case iconImage(id: String)
        case local(name: String)
        case system(name: String)
    }
}

public extension Navigation {
    enum AlertStyle: Codable, Equatable, Sendable {
        case actionSheet
        case alert

        #if os(iOS)
        var uiAlertControllerStyle: UIAlertController.Style {
            switch self {
            case .actionSheet:
                .actionSheet
            case .alert:
                .alert
            }
        }
        #endif
    }

    struct AlertModel: Identifiable, Codable, Equatable, Sendable {
        public init(id: UUID = UUID(), type: AlertStyle = .alert, title: String? = nil, message: String? = nil, buttons: [AlertButtonModel]? = nil) {
            self.id = id
            self.type = type
            self.title = title
            self.message = message
            self.buttons = buttons
        }

        public let id: UUID
        public let type: AlertStyle
        public let title: String?
        public var message: String?
        public let buttons: [AlertButtonModel]?
    }

    struct AlertButtonModel: Identifiable, Codable, Equatable, Sendable {
        public static func == (lhs: AlertButtonModel, rhs: AlertButtonModel) -> Bool {
            lhs.id == rhs.id
        }

        public enum AlertActionStyle: Equatable, Codable, Sendable {
            case `default`
            case cancel
            case destructive

            #if os(iOS)
            public var uiAlertActionStyle: UIAlertAction.Style {
                switch self {
                case .default:
                    return .default
                case .cancel:
                    return .cancel
                case .destructive:
                    return .destructive
                }
            }
            #endif
        }

        public init(id: UUID = UUID(), label: String, type: AlertActionStyle = .default, action: (@Sendable () -> Void)? = nil) {
            self.id = id
            self.label = label
            self.type = type
            self.action = action
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            id = try values.decode(UUID.self, forKey: .id)
            label = try values.decode(String.self, forKey: .label)
            type = try values.decode(AlertActionStyle.self, forKey: .type)
            action = nil
        }

        public var id: UUID
        let label: String
        let type: AlertActionStyle
        let action: (@Sendable () -> Void)?

        enum CodingKeys: CodingKey {
            case id, label, type
        }
    }
}

public extension Navigation {
    struct CodableClosure: Sendable, Codable, Equatable {
        public init(id: UUID = UUID(), _ completion: (@Sendable () -> Void)? = nil) {
            self.completion = completion
            self.id = id
        }

        let id: UUID
        var completion: (@Sendable () -> Void)?

        public static func == (lhs: CodableClosure, rhs: CodableClosure) -> Bool {
            return lhs.id == rhs.id && lhs.id == rhs.id
        }

        public init(from decoder: any Decoder) throws {
            completion = nil
            id = try decoder.container(keyedBy: CodingKeys.self).decode(UUID.self, forKey: .id)
        }

        enum CodingKeys: CodingKey {
            case id
        }
    }
}
