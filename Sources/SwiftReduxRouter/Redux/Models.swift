import Foundation
#if os(iOS)
import UIKit
#endif

#if canImport(UIKit)
public enum NavigationTarget: Codable, Sendable {
    case new(withName: String = UUID().uuidString, type: PresentationType = .regular)
    case navigationModel(NavigationModel, animate: Bool = true)
    case current(animate: Bool = true)
}

public enum PresentationType: Codable, Sendable {
    case tab
    case regular
}

public struct NavigationModel: Codable, Equatable, Sendable {
    public static func == (lhs: NavigationModel, rhs: NavigationModel) -> Bool {
        lhs.id == rhs.id
    }

    public var id: UUID
    public var name: String
    public var selectedPath: NavigationPath

    public var tab: NavigationTab?
    public var presentedPaths = [NavigationPath]()
    public var isPresented: Bool
    public let presentationType: PresentationType
    var animate: Bool

    public init(id: UUID = UUID(), name: String, selectedPath: NavigationPath, tab: NavigationTab? = nil, presentedPaths: [NavigationPath] = [], isPresented: Bool = true, presentationType: PresentationType = .regular) {
        self.id = id
        self.name = name
        self.isPresented = isPresented
        self.presentationType = presentationType
        self.selectedPath = selectedPath
        self.tab = tab
        self.presentedPaths = presentedPaths
        animate = true
    }

    public static func createInitModel(id: UUID = UUID(), name: String, selectedPath: NavigationPath, tab: NavigationTab? = nil) -> NavigationModel {
        NavigationModel(id: id, name: name, selectedPath: selectedPath, tab: tab, presentedPaths: [selectedPath], isPresented: false)
    }
}

public struct NavigationRoute: Codable {
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
        guard let url = URL(string: parameters.joined(separator: "/")) else { return nil }
        return NavigationPath(url)
    }
}

public struct NavigationPath: Identifiable, Codable, Sendable {
    public var id: UUID
    public var url: URL?
    public var hideNavigationBar: Bool
    public var title: String?

    public init(id: UUID = UUID(), _ url: URL? = nil, hideNavigationBar: Bool = false, title: String? = nil) {
        self.id = id
        self.url = url
        self.hideNavigationBar = hideNavigationBar
        self.title = title
    }

    public func pushAction(to target: NavigationTarget) -> NavigationActions.Push {
        return NavigationActions.Push(path: self, to: target)
    }

    public var path: String? {
        url?.path
    }
}

public struct NavigationTab: Codable, Sendable {
    public var name: String
    public var icon: Icon
    public var selectedIcon: Icon?
    public var badgeColor: UIColor?
    public var badgeValue: String?
    public init(name: String, icon: Icon, selectedIcon: Icon? = nil, badgeValue: String? = nil, badgeColor: UIColor? = nil) {
        self.name = name
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.badgeValue = badgeValue
        self.badgeColor = badgeColor
    }
}

public extension NavigationTab {
    enum Icon: Codable, Sendable {
        case local(name: String)
        case system(name: String)

        private enum CodingKeys: String, CodingKey {
            case name, type
        }

        private enum IconType: String, Codable {
            case local, system
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let type = try values.decode(IconType.self, forKey: .type)
            let name = try values.decode(String.self, forKey: .name)

            switch type {
            case .local:
                self = Icon.local(name: name)
            case .system:
                self = Icon.system(name: name)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .local(name):
                try container.encode(IconType.local, forKey: .type)
                try container.encode(name, forKey: .name)
            case let .system(name):
                try container.encode(IconType.system, forKey: .type)
                try container.encode(name, forKey: .name)
            }
        }
    }
}

#endif
