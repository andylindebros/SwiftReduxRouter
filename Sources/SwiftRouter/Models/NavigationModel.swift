import Foundation

public extension Navigation {
    /**
     Represents a `UINavigationController`. This model defines how the controller should be presented and which `UIViewController` instances should be included in the navigation stack.

      parameters:
     - parameter id: A unique id of the model
     - parameter routes: The supported routes that can be handled and opened using this navigation.
     - parameter selectedPath: The selected navigation path
     - parameter tab: Specifies whether the model should represent a tab within the tab bar.
     */
    struct Model: Codable, Equatable, Sendable, CustomStringConvertible {
        init(id: UUID = UUID(), routes: [Route]? = nil, selectedPath: Path, tab: Tab? = nil, presentedPaths: [Path] = [], isPresented: Bool = true, presentationType: PresentationType = .pageSheet(), selectedDetentIdentifier: String? = nil, animate: Bool = true) {
            self.id = id
            self.routes = routes
            self.isPresented = isPresented
            self.presentationType = presentationType
            self.selectedPath = selectedPath
            self.tab = tab
            self.presentedPaths = presentedPaths
            self.selectedDetentIdentifier = selectedDetentIdentifier
            self.animate = animate
        }

        public var description: String {
            "\(type(of: self))(\(tab?.name ?? id.uuidString))"
        }

        public static func == (lhs: Model, rhs: Model) -> Bool {
            lhs.id == rhs.id
        }

        public let id: UUID
        public let routes: [Route]?
        public var selectedPath: Path

        public var tab: Tab?
        public var presentedPaths = [Path]()
        public var isPresented: Bool
        public var presentationType: PresentationType
        public var selectedDetentIdentifier: String?
        public var shouldBeDismsised: Bool = false
        public var dismissCompletionAction: CodableClosure?
        var animate: Bool
        public var tipIdentifier: String?

        public static func create(id: UUID = UUID(), routes: [Route]? = nil, selectedPath: Path, tab: Tab? = nil) -> Model {
            Model(id: id, routes: routes, selectedPath: selectedPath, tab: tab, presentedPaths: [selectedPath], isPresented: false)
        }
    }
}
