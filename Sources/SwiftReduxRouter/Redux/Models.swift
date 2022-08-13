import Foundation

public enum NavigationTarget: Codable {
    case new(withName: String = UUID().uuidString)
    case navigationModel(NavigationModel)
    case current
}

public struct NavigationModel: Codable, Equatable {
    public static func == (lhs: NavigationModel, rhs: NavigationModel) -> Bool {
        lhs.id == rhs.id
    }

    public var id: UUID
    public var name: String
    public var selectedPath: NavigationPath

    public var tab: NavigationTab?
    public var presentedPaths = [NavigationPath]()
    public var isPresented: Bool

    public init(id: UUID = UUID(), name: String, selectedPath: NavigationPath, tab: NavigationTab? = nil, presentedPaths: [NavigationPath] = [], isPresented: Bool = true) {
        self.id = id
        self.name = name
        self.isPresented = isPresented

        self.selectedPath = selectedPath

        self.tab = tab

        self.presentedPaths = presentedPaths
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
        return NavigationPath(parameters.joined(separator: "/"))
    }
}

public struct NavigationPath: Identifiable, Codable {
    public var id: UUID
    public var path: String
    public var hideNavigationBar: Bool
    public var title: String?

    public init(id: UUID = UUID(), _ path: String, hideNavigationBar: Bool = false, title: String? = nil) {
        self.id = id
        self.path = path
        self.hideNavigationBar = hideNavigationBar
        self.title = title
    }

    public func pushAction(to target: NavigationTarget) -> NavigationActions.Push {
        return NavigationActions.Push(path: self, to: target)
    }
}

public struct NavigationTab: Codable {
    public var name: String
    public var icon: Icon
    public var selectedIcon: Icon?

    public init(name: String, icon: Icon, selectedIcon: Icon? = nil) {
        self.name = name
        self.icon = icon
        self.selectedIcon = selectedIcon
    }
}

public extension NavigationTab {
    enum Icon: Codable {
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
