import Foundation

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

public struct NavigationPath: Encodable {
    public var id: UUID
    public var path: String

    public init(id: UUID = UUID(), _ path: String) {
        self.id = id
        self.path = path
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
