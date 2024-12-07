import Foundation
#if os(iOS)
    import UIKit
#endif

public enum DismissTarget: Equatable, Codable, Sendable {
    case currentNavigationModel(animated: Bool = true)
    case navigationModel(NavigationModel, animated: Bool = true)
    case navigationPath(NavPath, animated: Bool = true)
}

public enum NavigationTarget: Equatable, Codable, Sendable {
    case new(withModelPath: NavPath? = nil, type: PresentationType = .regular(), animate: Bool = true)
    case navigationModel(NavigationModel, animate: Bool = true)
    case current(animate: Bool = true)
}

public extension PresentationType {
    enum Detent: Equatable, Codable, Sendable {
        case medium, large, custom(identifier: String, height: Double)

        public var detent: UISheetPresentationController.Detent {
            switch self {
            case .medium:
                return .medium()
            case .large:
                return .large()
            case let .custom(identifier, height):
                if #available(iOS 16.0, *) {
                    let identifier = UISheetPresentationController.Detent.Identifier(identifier)
                    return .custom(identifier: identifier) { _ in
                        height
                    }
                } else {
                    return .medium()
                }
            }
        }
    }
}

public enum PresentationType: Equatable, Codable, Sendable {
    case regular(preventDismissal: Bool = false)
    case fullscreen
    case detents([PresentationType.Detent], selected: PresentationType.Detent? = nil, largestUndimmedDetentIdentifier: PresentationType.Detent? = nil, preventDismissal: Bool = false, prefersGrabberVisible: Bool = false, preferredCornerRadius: Double? = nil, prefersScrollingExpandsWhenScrolledToEdge: Bool = true)

    var style: UIModalPresentationStyle {
        switch self {
        case .regular, .detents:
            .pageSheet
        case .fullscreen:
            .overFullScreen
        }
    }

    var preventDismissal: Bool? {
        switch self {
        case let .regular(preventDismissal), let .detents(_, _, _, preventDismissal, _, _, _):
            preventDismissal
        case .fullscreen:
            nil
        }
    }

    var detentItems: [Detent]? {
        switch self {
        case let .detents(items, _, _, _, _, _, _):
            items
        default:
            nil
        }
    }

    var selectedDetent: Detent? {
        switch self {
        case let .detents(_, selectedDetent, _, _, _, _, _):
            selectedDetent
        default:
            nil
        }
    }
}

public struct NavigationRoute: Equatable, Codable, Sendable, CustomStringConvertible {
    public init(_ path: String, name: String? = nil) {
        self.path = path
        self.name = name
    }

    public var path: String
    public var name: String?

    public func reverse(params: [String: String] = [:]) -> NavPath? {
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
        var str = parameters.joined(separator: "/")

        if str.prefix(1) != "/" {
            str = "/" + str
        }
        guard let url = URL(string: str) else { return nil }
        return .create(url, name: name)
    }

    public var description: String {
        "\(type(of: self))(\(path))"
    }
}

public struct NavPath: Identifiable, Equatable, Codable, Sendable, CustomStringConvertible {
    public var id: UUID
    public let url: URL?
    public let name: String?

    public init(id: UUID = UUID(), _ url: URL? = nil, _ name: String? = nil) {
        self.id = id
        self.url = url
        self.name = name
    }

    public var path: String? {
        url?.path
    }

    public static func create(_ urlString: String, name: String? = nil) -> NavPath? {
        guard let url = URL(string: urlString) else { return nil }
        return .init(url, name)
    }

    public static func create(_ url: URL?, name: String? = nil) -> NavPath? {
        guard let url = url else { return nil }
        return .init(url, name)
    }

    public var description: String {
        "\(type(of: self))(\(url?.path ?? "unknown"))"
    }
}

public struct NavigationTab: Codable, Sendable, CustomStringConvertible {
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

    public var description: String {
        "\(type(of: self))(\(name))"
    }
}

public extension NavigationTab {
    struct IconImage: Identifiable, Sendable {
        public init(id: String, image: UIImage) {
            self.id = id
            self.image = image
        }

        public let id: String
        public let image: UIImage?
    }

    enum Icon: Codable, Sendable {
        case iconImage(id: String)
        case local(name: String)
        case system(name: String)

        private enum CodingKeys: String, CodingKey {
            case name, type, iconImage
        }

        private enum IconType: String, Codable {
            case local, system, iconImage
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let type = try values.decode(IconType.self, forKey: .type)
            let name = try values.decode(String.self, forKey: .name)

            switch type {
            case .iconImage:
                self = Icon.iconImage(id: name)
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
            case let .iconImage(imageID):
                try container.encode(IconType.iconImage, forKey: .type)
                try container.encode(imageID, forKey: .iconImage)
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
        if let action = action {
            actions = [action]
        }
    }

    public init(id: UUID = UUID(), label: String, type: UIAlertAction.Style = .default, actions: [any NavigationActionProvider]) {
        self.id = id
        self.label = label
        self.type = type
        self.actions = actions
    }

    public var id: UUID
    let label: String
    let type: UIAlertAction.Style
    var actions: [any NavigationActionProvider]?

    enum CodingKeys: CodingKey {
        case id, label, type
    }
}

extension UIAlertAction.Style: Codable {}
extension UIAlertController.Style: Codable {}
