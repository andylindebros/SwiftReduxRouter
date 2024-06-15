import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

public protocol NavigationActionProvider: Codable, CustomLogging, Sendable {}

public protocol NavigationJumpStateAction: CustomLogging, Sendable {
    var navigationState: NavigationState { get }
}

public typealias NavigationDispatcher = (NavigationActionProvider) -> Void

public indirect enum NavigationAction: Equatable, NavigationActionProvider {
    case add(path: NavigationPath?, to: NavigationTarget)
    case dismiss(NavigationModel)
    case dismissPath(NavigationPath)
    case prepareAndDismiss(NavigationModel, animated: Bool = true, completionAction: NavigationAction? = nil)
    case setSelectedPath(to: NavigationPath, in: NavigationModel)
    case setNavigationDismsissed(NavigationModel)
    case selectTab(by: UUID)
    case replace(path: NavigationPath, with: NavigationPath, in: NavigationModel)
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

    public var description: String {
        let desc = "\(type(of: self))"
        switch self {
        case let .multiAction(actions): return "\(desc).multiAction \(actions.map { $0.description })"
        case .setAvailableRoutes: return "\(desc).setAvailableRoutes"
        case .setAvailableNavigationModelRoutes: return "\(desc).setAvailableNavigationModelRoutes"
        case let .dismissedAlert(model):
            return "\(desc).dismissedAlert(\(model))"
        case let .alert(model):
            return "\(desc).alert(\(model))"
        case let .add(path: path, to: target):
            return "\(desc).add path: \(path?.description ?? "nil"), to: \(target)"
        case let .dismiss(model):
            return "\(desc).dismiss \(model)"
        case let .dismissPath(path):
            return "\(desc).dismissPath \(path)"
        case let .setSelectedPath(to: path, in: model):
            return "\(desc).setSelectedPath to: \(path) in: \(model)"
        case let .setNavigationDismsissed(model):
            return "\(desc).setNavigationDismsissed \(model)"
        case let .selectTab(by: id):
            return "\(desc).selectTab by: \(id)"
        case let .replace(path: path, with: newPath, in: model):
            return "\(desc).replace path: \(path) with newPath: \(newPath.path ?? path.id.uuidString) in: \(model)"
        case let .setIcon(to: value, withModelID: modelID):
            return "\(desc).setIcon to: \(value) withModelID: \(modelID.uuidString)"

        case let .setBadgeValue(to: value, withModelID: modelID, withColor: _):
            return "\(desc).setBadgeValue to: \(value ?? "") withModelID: \(modelID.uuidString)"

        case let .deeplink(deeplink):
            return "\(desc).deeplink with url: \(deeplink.url.path)"
        case let .selectedDetentChanged(to: identifier, in: navigationModel):
            return "\(desc).selectedDetentChanged to: \(identifier) in: \(navigationModel.id)"
        case let .prepareAndDismiss(model, animated, completionAction):
            return "\(desc).prepareForDismissal \(model) animated: \(animated), completionAction: \(completionAction?.description ?? "nil")"
        }
    }

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

        public var description: String {
            "\(type(of: self))(url: \(url.path)) ? \(url.query != nil ? "?\(url.query ?? "")" : "")"
        }

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
                    if let foundPath = model.presentedPaths.first(where: { $0.path == newURL.absoluteString }) {
                        return NavigationAction.setSelectedPath(to: foundPath, in: model)
                    }

                    // Present new path to found model
                    return NavigationAction.add(path: NavigationPath(newURL), to: .navigationModel(model, animate: true))
                }
            } else {
                // Push new path to known navigationModel (found in navigation routes)
                if
                    let pattern = URLMatcher().match(url.path, from: state.observed.availableNavigationModelRoutes.compactMap { $0.path }, ensureComponentsCount: false),
                    //let newPath = NavigationPath.create(URL(string: url.path.replacingOccurrences(of: pattern.path, with: "")))
                    let newPath = NavigationPath.create(createNewURL(from: url, removeFromPath: pattern.path))
                {
                    return NavigationAction.add(path: newPath, to: .new(withModelPath: NavigationPath(URL(string: pattern.path)), type: .regular()))

                    // push to new navigationModel
                } else if let newPath = NavigationPath.create(createNewURL(from: url, removeFromPath: "")) {
                    return NavigationAction.add(path: newPath, to: .new())
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
