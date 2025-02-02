import Foundation
import SwiftUI

public extension Navigation {
    protocol ActionProvider: Codable, Sendable {}

    typealias NavigationDispatcher = (ActionProvider) -> Void
}

public extension Navigation {
    /**
     The type of action to perform in order to modify the navigation state.
     */
    indirect enum Action: Sendable, Equatable, ActionProvider {
        /**
         Presents an alert

         - parameter alertModel: The model that provides necessary data  to present the alert
         */
        case alert(AlertModel)

        /**
         Dismissess an alert
         - parameter alertModel: The alert model to dimsiss
         */
        case dismissedAlert(with: AlertModel)

        /**
         Dismisses a view from the navigation stack

         - parameter target: the target of the dismissal
         - parameter completion: action to trigger when dismissal has completed
         */
        case dismiss(DismissTarget)

        /**
         Handle multiple actions at once without trigger multiple renderings

         - parameter actions: the list of actions to handle
         */
        case multiAction([Action])

        /**
         presents or push a new viewController to the navigation stack

         - parameter path: The path to add to the stack
         - parameter target: The target to use
         */
        case open(path: Path?, in: Target = .current())

        /**
         Replaces an existing path with a new without any animations

          - parameter path: The path to replace
          - parameter replacement: The path to replace with
          - parameter model: The model that presents the  path
          */
        case replace(path: Path, with: Path, in: Model)

        /**
         Updates the selected detent

         - parameter newValue: The new identifier to set as selected detent
         - parameter model: The model that presents the  path
         */
        case selectedDetentIdentifierChanged(to: String, in: Model)

        /**
         Selects a tab
         - parameter id: the uuid of the model that represents the selected tab
         */
        case selectTab(by: UUID)

        /**
         Provides the list of available routes that the state will use to match urls with.

         - parameter routes: The list of available routes
         */
        case setAvailableRoutes(to: [Route])

        /**
         Updates the badge value to the tab

         - parameter newValue: The value to display in the badge
         - parameter modelID: The uuid of the model that represents the tab
         - parameter color: The color to use when presenting the badge
         */
        case setBadgeValue(to: String?, withModelID: UUID, withColor: Color? = nil)

        /**
         Internal use for the navigationController to tell the state that it has completed the dismissal.

         Note! Don't use this action to trigger a dismissal. This action is for internal use triggered from navigationController delegate methods.
         Use `dismiss` to trigger dismissals instead

         - parameter navigationModel: The navigationModel that has completed the dismissal
         */
        case setNavigationDismsissed(Model)

        /**
         Updates a detented presented action sheet with new detents

         - parameter detentsModel: The options for the detents
         - parameter model: The model that is presenting the action sheet
         */
        case setNewDetents([PresentationType.Detent], selected: PresentationType.Detent, in: Model)

        /**
         Selects a path in a navigation

         - parameter path: The path to select in the navigation
         - parameter model: The model that should select the path
         */
        case setSelectedPath(to: Path, in: Model)

        /**
         Adds a tip identifier for the tabController to present tips

         - parameter identifier: The value of the identifier
         - parameter model: The model representation of the tab
         */
        case setTabTipIdentifier(to: String?, byNavigationModel: Navigation.Model)

        /**
         Updates the URL of a path. It will update the path of routeViewModel in a route

         - parameter path: The path to update
         - parameter newUrl: The new url replace the url of the path with
         - parameter model: The model that presents the path
         */
        case update(path: Path, withURL: URL?, in: Model)

        /**
         Sets the  entire state.
         Note: In general, Use other actions to modify the state. This action might have unexpected behaviour.
         - parameter state: The new State
         */
        case setLoadedState(to: Navigation.State)

        /**
         Remove all untracked views such as action sheets, alerts, other presenting windows
          */
        case untrackedViewsRemoved
        /**
         Provides actions for a URL depending on the navigation state
         - parameter url: The url to change the state with
         - parameter accessLevel: Minimum required accessLevel required to access a matched route
         */
        public struct Deeplink: Sendable, Equatable, ActionProvider {
            public init?(with url: URL?, accessLevel: RouteAccessLevel) {
                guard let url = url else { return nil }
                self.url = url
                self.accessLevel = accessLevel
            }

            let url: URL
            let accessLevel: RouteAccessLevel

            private func createNewURL(from url: URL, removeFromPath: String) -> URL? {
                var urlComponents = URLComponents(string: url.absoluteString)
                let newPath = url.path.replaceFirstExpression(of: removeFromPath, with: "")
                guard !newPath.isEmpty else {
                    return url
                }

                urlComponents?.path = newPath
                return urlComponents?.url
            }

            public func action(for state: State, preferredTarget: Navigation.Target? = nil) -> ActionProvider? {
                // Check if the url is supported by a tab
                if preferredTarget == nil, let (model, route) = findNavigationModel(in: state) {
                    let newURL = createNewURL(from: url, removeFromPath: route.parentPath)

                    // Exact: 100% match in a tab
                    if
                        let newURL = newURL,
                        let matchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.pattern }),
                        let currentPath = model.presentedPaths.first(where: { $0.path == newURL.path }),
                        let route = State.route(by: matchResult, in: state.observed.availableRoutes),
                        route.accessLevel.grantAccess(for: .private)
                    {
                        return Navigation.Action.setSelectedPath(to: currentPath, in: model)
                    }

                    // Similar: URL has an similar match in a tab
                    if
                        let newURL = newURL,
                        let newMatchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.pattern }),
                        let currentPath = model.presentedPaths.first(where: { $0.urlMatchResult(of: state.observed.availableRoutes)?.pattern == newMatchResult.pattern }),
                        let route = State.route(by: newMatchResult, in: state.observed.availableRoutes),
                        !route.rules.isEmpty,
                        route.validate(result: newMatchResult, forAccessLevel: .private)
                    {
                        return Navigation.Action.update(path: currentPath, withURL: newURL, in: model)
                    }

                    // Present new path to found model
                    guard let navPath = State.validate(path: Path.create(newURL), in: state) else {
                        return nil
                    }
                    return Action {
                        if let preExecutionDeeplinkOpenAction = route.preExecutionDeeplinkOpenAction {
                            preExecutionDeeplinkOpenAction
                        }
                        Action.open(path: navPath, in: .model(model, animate: true))
                    }

                } else {
                    // Push new path to new or preferred navigationModel
                    if
                        let matchResult = URLMatcher().match(
                            url.path,
                            from: state.observed.availableRoutes.filter { $0.accessLevel.grantAccess(for: accessLevel) }.compactMap { $0.pattern
                            },
                            ensureComponentsCount: true
                        ),
                        let route = State.route(by: matchResult, in: state.observed.availableRoutes),
                        route.validate(result: matchResult, forAccessLevel: accessLevel),
                        let newPath = Path.create(createNewURL(from: url, removeFromPath: ""))
                    {
                        return Action {
                            if let preExecutionDeeplinkOpenAction = route.preExecutionDeeplinkOpenAction {
                                preExecutionDeeplinkOpenAction
                            }
                            Action.open(path: newPath, in: preferredTarget ?? .new())
                        }
                    }
                    return nil
                }
            }

            private func findNavigationModel(in state: State) -> (Model, Route)? {
                guard
                    let matchResult = URLMatcher().match(url.path, from: state.observed.navigationModels.compactMap { $0.routes }.flatMap { $0 }.compactMap { $0.pattern }),
                    // swiftlint:disable:next contains_over_filter_count
                    let navigationModel = state.observed.navigationModels.first(where: { navigationModel in (navigationModel.routes ?? []).filter { route in
                        route.validate(result: matchResult, forAccessLevel: accessLevel)
                    }.count > 0
                    }),
                    let route = navigationModel.routes?.first(where: { $0.pattern == matchResult.pattern })
                else {
                    return nil
                }
                return (navigationModel, route)
            }
        }
    }
}

@resultBuilder
public enum MultiActionBuilder {
    public static func buildEither(first component: [Navigation.Action]) -> [Navigation.Action] {
        return component
    }

    public static func buildEither(second component: [Navigation.Action]) -> [Navigation.Action] {
        return component
    }

    public static func buildOptional(_ component: [Navigation.Action]?) -> [Navigation.Action] {
        return component ?? []
    }

    public static func buildExpression(_ expression: Navigation.Action) -> [Navigation.Action] {
        return [expression]
    }

    public static func buildExpression(_: ()) -> [Navigation.Action] {
        return []
    }

    public static func buildBlock(_ components: [Navigation.Action]...) -> [Navigation.Action] {
        return components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[Navigation.Action]]) -> [Navigation.Action] {
        Array(components.joined())
    }
}

public extension Navigation.Action {
    init(@MultiActionBuilder _ actions: () -> [Navigation.Action]) {
        self = .multiAction(actions())
    }
}
