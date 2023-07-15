import Foundation
#if os(iOS)
    import UIKit
#endif

public enum NavigationTarget: Equatable, Codable, CustomLogging, Sendable {
    case new(withModelPath: NavigationPath? = nil, type: PresentationType = .regular)
    case navigationModel(NavigationModel, animate: Bool = true)
    case current(animate: Bool = true)

    public var description: String {
        switch self {
        case let .new(path, type):
            return ".new(\(path?.path ?? "")\(type != .regular ? " \(type)" : ""))"
        case .navigationModel:
            return ".navigationModel"
        case .current:
            return ".current"
        }
    }
}

public enum PresentationType: Equatable, Codable, Sendable {
    case tab
    case regular
}

public struct NavigationRoute: Codable, Sendable {
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
        return NavigationPath.create(url)
    }
}

public struct NavigationPath: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var url: URL?

    public init(id: UUID = UUID(), _ url: URL? = nil) {
        self.id = id
        self.url = url
    }

    public var path: String? {
        url?.path
    }

    public static func create(_ urlString: String) -> NavigationPath? {
        guard let url = URL(string: urlString) else { return nil }
        return NavigationPath(url)
    }

    public static func create(_ url: URL?) -> NavigationPath? {
        guard let url = url else { return nil }
        return NavigationPath(url)
    }
}

public struct NavigationTab: Codable, Sendable {
    public var name: String
    public var icon: Icon
    public var selectedIcon: Icon?
    #if canImport(UIKit)
        public var badgeColor: UIColor?
    #endif
    public var badgeValue: String?

    #if canImport(UIKit)
        public init(name: String, icon: Icon, selectedIcon: Icon? = nil, badgeValue: String? = nil, badgeColor: UIColor? = nil) {
            self.name = name
            self.icon = icon
            self.selectedIcon = selectedIcon
            self.badgeValue = badgeValue
            self.badgeColor = badgeColor
        }
    #else
        public init(name: String, icon: Icon, selectedIcon: Icon? = nil, badgeValue: String? = nil) {
            self.name = name
            self.icon = icon
            self.selectedIcon = selectedIcon
            self.badgeValue = badgeValue
        }
    #endif
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

public struct AlertModel: Identifiable, Codable, Equatable, Sendable {
    public init(id: UUID = UUID(), type: UIAlertController.Style = .alert, title: String? = nil, message: String? = nil, buttons: [AlertButtonModel]? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.buttons = buttons
    }

    public let id: UUID
    public let type: UIAlertController.Style
    public let title: String?
    public var message: String?
    public let buttons: [AlertButtonModel]?
}

public struct AlertButtonModel: Identifiable, Codable, Equatable, Sendable {
    public static func == (lhs: AlertButtonModel, rhs: AlertButtonModel) -> Bool {
        lhs.id == rhs.id
    }

    public init(id: UUID = UUID(), label: String, type: UIAlertAction.Style = .default, action: (any NavigationActionProvider)? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.action = action
    }

    public var id: UUID
    let label: String
    let type: UIAlertAction.Style
    var action: (any NavigationActionProvider)?

    enum CodingKeys: CodingKey {
        case id, label, type
    }
}

extension UIAlertAction.Style: Codable {}
extension UIAlertController.Style: Codable {}
