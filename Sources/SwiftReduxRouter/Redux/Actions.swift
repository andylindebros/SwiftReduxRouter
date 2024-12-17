import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

public protocol NavigationActionProvider: Codable, Sendable {}

public typealias NavigationDispatcher = (NavigationActionProvider) -> Void

public indirect enum NavigationAction: Equatable, NavigationActionProvider {
    case open(path: NavPath?, in: NavigationTarget = .current())
    case dismiss(DismissTarget, withCompletion: NavigationAction? = nil)
    case setSelectedPath(to: NavPath, in: NavigationModel)
    case setNavigationDismsissed(NavigationModel)
    case selectTab(by: UUID)
    case replace(path: NavPath, with: NavPath, in: NavigationModel)
    case update(path: NavPath, withURL: URL?, in: NavigationModel)
    case setIcon(to: String, withModelID: UUID)
    case alert(AlertModel)
    case dismissedAlert(with: AlertModel)
    case selectedDetentChanged(to: String, in: NavigationModel)
    case setAvailableRoutes(to: [NavigationRoute])
    case multiAction([NavigationAction])
    #if canImport(UIKit)
        case setBadgeValue(to: String?, withModelID: UUID, withColor: UIColor? = nil)
    #else
        case setBadgeValue(to: String?, withModelID: UUID, withColor: String? = nil)
    #endif
    case deeplink(Deeplink)
    case shouldScrollToTop(NavPath)

    /**
     Provides actions for a URL depending on the NavigationState
     - parameter url: The url to change the state with
     */
    public struct Deeplink: Equatable, NavigationActionProvider {
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
            guard newPath != "" else {
                return url
            }

            urlComponents?.path = newPath
            return urlComponents?.url
        }

        public func action(for state: Navigation.State) -> NavigationActionProvider? {
            if let (model, route) = findNavigationModel(in: state) {
                let newURL = createNewURL(from: url, removeFromPath: route.parentPath)

                // Exact: 100% match
                if
                    let newURL = newURL,
                    let matchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.path }),
                    let currentPath = model.presentedPaths.first(where: { $0.urlMatchResult(of: state.observed.availableRoutes)?.pattern == matchResult.pattern }),
                    currentPath.path == newURL.path,
                    let route = Navigation.State.route(by: matchResult, in: state.observed.availableRoutes),
                    route.accessLevel.grantAccess(for: .private)
                {
                    return NavigationAction.setSelectedPath(to: currentPath, in: model)
                }

                // Similar: URL has an similar match
                if
                    let newURL = newURL,
                    let newMatchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.path }),
                    let currentPath = model.presentedPaths.first(where: { $0.urlMatchResult(of: state.observed.availableRoutes)?.pattern == newMatchResult.pattern }),
                    let route = Navigation.State.route(by: newMatchResult, in: state.observed.availableRoutes),
                    !route.rules.isEmpty,
                    route.validate(result: newMatchResult, forAccessLevel: .private)
                {
                    return NavigationAction {
                        NavigationAction.update(path: currentPath, withURL: newURL, in: model)
                        NavigationAction.setSelectedPath(to: currentPath, in: model)
                    }
                }

                // Present new path to found model
                guard let navPath = Navigation.State.validate(path: NavPath.create(newURL), in: state) else {
                    return NavigationAction.setSelectedPath(to: model.selectedPath, in: model)
                }
                return NavigationAction.open(path: navPath, in: .navigationModel(model, animate: true))

            } else {
                // Push new path to known navigationModel (found in navigation routes)
                if URLMatcher().match(
                    url.path,
                    from: state.observed.availableRoutes.filter{ $0.accessLevel.grantAccess(for: accessLevel) }.compactMap { $0.path
                    },
                    ensureComponentsCount: true
                ) != nil,
                    let newPath = NavPath.create(createNewURL(from: url, removeFromPath: ""))
                {
                    return NavigationAction.open(path: newPath, in: .new())
                }
                return nil
            }
        }

        private func findNavigationModel(in state: Navigation.State) -> (NavigationModel, NavigationRoute)? {
            guard
                let matchResult = URLMatcher().match(url.path, from: state.observed.navigationModels.compactMap { $0.routes }.flatMap { $0 }.compactMap { $0.path }),
                let navigationModel = state.observed.navigationModels.first(where: { navigationModel in
                    return (navigationModel.routes ?? []).filter { route in
                        return route.validate(result: matchResult, forAccessLevel: accessLevel)
                    }.count > 0
                }),
                let route = navigationModel.routes?.first(where: { $0.path == matchResult.pattern })
            else {
                return nil
            }
            return (navigationModel, route)
        }
    }
}

@resultBuilder
public enum MultiActionBuilder {
    public static func buildBlock(_ content: NavigationAction...) -> [NavigationAction] {
        Array(
            content.compactMap { $0 }
        )
    }
}

public extension NavigationAction {
    init(@MultiActionBuilder _ actions: () -> [NavigationAction]) {
        self = .multiAction(actions())
    }
}
