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
    case open(path: NavPath?, in: NavigationTarget)
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
    case setAvailableNavigationModelRoutes(to: [NavigationRoute])
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
        public init?(with url: URL?) {
            guard let url = url else { return nil }
            self.url = url
        }

        let url: URL

        private func createNewURL(from url: URL, removeFromPath: String) -> URL? {
            var urlComponents = URLComponents(string: url.absoluteString)
            urlComponents?.path = url.path.replaceFirstExpression(of: removeFromPath, with: "")

            return urlComponents?.url
        }

        public func action(for state: Navigation.State) -> NavigationActionProvider? {
            if let model = findNavigationModel(in: state) {
                let newURL = createNewURL(from: url, removeFromPath: model.path?.url?.absoluteString ?? "")
                // Select: URL has a excat match
                if newURL == model.selectedPath.url || url.path == model.path?.url?.absoluteString {
                    return NavigationAction.setSelectedPath(to: model.selectedPath, in: model)
                }

                if let newURL = newURL {
                    // Found and select already mathing path in model
                    if let foundPath = model.presentedPaths.first(where: { $0.path == newURL.path }) {
                        return NavigationAction.setSelectedPath(to: foundPath, in: model)
                    }

                    // Present new path to found model
                    return NavigationAction.open(path: NavPath(newURL), in: .navigationModel(model, animate: true))
                }
            } else {
                // Push new path to known navigationModel (found in navigation routes)
                if
                    let pattern = URLMatcher().match(url.path, from: state.observed.availableNavigationModelRoutes.compactMap { $0.path }, ensureComponentsCount: false),
                    // let newPath = NavPath.create(URL(string: url.path.replacingOccurrences(of: pattern.path, with: "")))
                    let newPath = NavPath.create(createNewURL(from: url, removeFromPath: pattern.path))
                {
                    return NavigationAction.open(path: newPath, in: .new(withModelPath: NavPath(URL(string: pattern.path)), type: .regular()))

                    // push to new navigationModel
                } else if URLMatcher().match(
                    url.path,
                    from: state.observed.availableRoutes.compactMap { $0.path
                    },
                    ensureComponentsCount: true
                ) != nil,
                    let newPath = NavPath.create(createNewURL(from: url, removeFromPath: ""))
                {
                    return NavigationAction.open(path: newPath, in: .new())
                }
                return nil
            }
            return nil
        }

        private func findNavigationModel(in state: Navigation.State) -> NavigationModel? {
            guard
                let pattern = URLMatcher().match(url.path, from: state.observed.navigationModels.compactMap { $0.path?.url?.absoluteString }, ensureComponentsCount: false)?.pattern,
                let navigationModel = state.observed.navigationModels.first(where: { $0.path?.url?.absoluteString == pattern })
            else {
                return nil
            }
            return navigationModel
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
