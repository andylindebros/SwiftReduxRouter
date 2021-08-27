import Foundation
import ReSwift

public struct NavigationSession: Encodable, Equatable {
    public static func == (lhs: NavigationSession, rhs: NavigationSession) -> Bool {
        lhs.id == rhs.id
    }

    public var id = UUID()
    public var name: String
    public var nextPath: NavigationPath
    public var selectedPath: NavigationPath
    public var tab: NavigationTab?
    public var presentedPaths = [NavigationPath]()

    public init(name: String, path: NavigationPath, selectedPath: NavigationPath? = nil, tab: NavigationTab? = nil) {
        self.name = name
        nextPath = path

        if let selectedPath = selectedPath {
            self.selectedPath = selectedPath
        } else {
            self.selectedPath = path
        }

        self.tab = tab

        presentedPaths.append(path)
    }
}

public struct NavigationRoute: Encodable {
    public init(_ path: String) {
        self.path = path
    }

    public var path: String

    public func reverse(params: [String: String] = [:]) -> NavigationPath? {
        let urlMatcher = URLMatcher()
        let components = urlMatcher.pathComponents(from: path)
        var parameters: [String] = []
        for component in components {
            switch component {
            case .plain:
                parameters.append(component.value)
            case .placeholder:
                guard let value = params[component.value] else {
                    return nil
                }
                parameters.append(value)
            }
        }
        return NavigationPath(parameters.joined(separator: "/"))
    }
}

public struct NavigationPath: Encodable {
    public var id: UUID
    public var path: String

    public init(id: UUID = UUID(), _ path: String) {
        self.id = id
        self.path = path
    }

    public func pushAction(to target: String) -> Action {
        return NavigationActions.Push(path: self, target: target)
    }
}

public struct NavigationTab: Codable {
    public var name: String
    public var icon: String
    public var selectedIcon: String?

    public init(name: String, icon: String, selectedIcon: String? = nil) {
        self.name = name
        self.icon = icon
        self.selectedIcon = selectedIcon
    }
}

public enum NavigationGoBackIdentifier: String {
    case back = ":back"
    case root = ":root"
}
