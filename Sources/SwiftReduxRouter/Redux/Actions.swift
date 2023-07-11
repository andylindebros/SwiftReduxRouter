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

public enum NavigationAction: Equatable, NavigationActionProvider {
    case add(path: NavigationPath, to: NavigationTarget)
    case dismiss(NavigationModel)
    case setSelectedPath(to: NavigationPath, in: NavigationModel)
    case setNavigationDismsissed(NavigationModel)
    case selectTab(by: UUID)
    case replace(path: NavigationPath, with: NavigationPath, in: NavigationModel)
    case setIcon(to: String, withModelID: UUID)
    #if canImport(UIKit)
        case setBadgeValue(to: String?, withModelID: UUID, withColor: UIColor? = nil)
    #else
        case setBadgeValue(to: String?, withModelID: UUID, withColor: String? = nil)
    #endif
    case deeplink(Deeplink)

    public var description: String {
        let desc = "\(type(of: self))"
        switch self {
        case let .add(path: path, to: target):
            return "\(desc).add path: \(path.path ?? path.id.uuidString), to: \(target)"
        case let .dismiss(model):
            return "\(desc).dismiss \(model)"
        case let .setSelectedPath(to: path, in: model):
            return "\(desc).setSelectedPath to: \(path.path ?? path.id.uuidString) in: \(model)"
        case let .setNavigationDismsissed(model):
            return "\(desc).setNavigationDismsissed \(model)"
        case let .selectTab(by: id):
            return "\(desc).selectTab by: \(id)"
        case let .replace(path: path, with: newPath, in: model):
            return "\(desc).replace path: \(path.path ?? path.id.uuidString) with newPath: \(newPath.path ?? path.id.uuidString) in: \(model)"
        case let .setIcon(to: value, withModelID: modelID):
            return "\(desc).setIcon to: \(value) withModelID: \(modelID.uuidString)"

        case let .setBadgeValue(to: value, withModelID: modelID, withColor: _):
            return "\(desc).setBadgeValue to: \(value ?? "") withModelID: \(modelID.uuidString)"

        case let .deeplink(deeplink):
            return "\(desc).deeplink with url: \(deeplink.url.path)"
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
            "\(type(of: self))(url: \(url.path))"
        }
        public func action(for state: NavigationState) -> NavigationActionProvider? {
            if let model = findNavigationModel(in: state) {
                let newURL = URL(string: url.path.replacingOccurrences(of: model.path?.url?.absoluteString ?? "", with: ""))

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
                    let pattern = URLMatcher().match(url.path, from: state.navigationModelRoutes.compactMap { $0.path }, ensureComponentsCount: false),
                    let newPath = NavigationPath.create(URL(string: url.path.replacingOccurrences(of: pattern.path, with: "")))
                {
                    return NavigationAction.add(path: newPath, to: .new(withModelPath: NavigationPath(URL(string: pattern.path)), type: .regular))

                    // push to new navigationModel
                } else if let newPath = NavigationPath.create(URL(string: url.path)) {
                    return NavigationAction.add(path: newPath, to: .new())
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
