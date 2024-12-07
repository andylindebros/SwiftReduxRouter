import Foundation

public struct NavigationModel: Codable, Equatable, Sendable, CustomStringConvertible {
    public init(id: UUID = UUID(), path: NavPath? = nil, selectedPath: NavPath, parentNavigationModelId: UUID = UUID(), parentNavigationModelName: String? = nil, tab: NavigationTab? = nil, presentedPaths: [NavPath] = [], isPresented: Bool = true, presentationType: PresentationType = .regular(), selectedDetentIdentifier: String? = nil, animate: Bool = true) {
        self.id = id
        self.path = path
        self.isPresented = isPresented
        self.presentationType = presentationType
        self.selectedPath = selectedPath
        self.tab = tab
        self.presentedPaths = presentedPaths
        self.selectedDetentIdentifier = selectedDetentIdentifier
        self.animate = animate
        self.parentNavigationModelId = parentNavigationModelId
        self.parentNavigationModelName = parentNavigationModelName
    }

    public var description: String {
        "\(type(of: self))(\(path?.name ?? path?.path ?? id.uuidString))"
    }

    public static func == (lhs: NavigationModel, rhs: NavigationModel) -> Bool {
        lhs.id == rhs.id
    }

    public let id: UUID
    public let parentNavigationModelId: UUID
    public let parentNavigationModelName: String?
    public let path: NavPath?
    public var selectedPath: NavPath

    public var tab: NavigationTab?
    public var presentedPaths = [NavPath]()
    public var isPresented: Bool
    public var presentationType: PresentationType
    public var selectedDetentIdentifier: String?
    public var shouldBeDismsised: Bool = false
    public var dismissCompletionAction: NavigationAction?
    var animate: Bool

    public static func createInitModel(id: UUID = UUID(), path: NavPath?, selectedPath: NavPath, tab: NavigationTab? = nil, parentNavigationModelId: UUID = .init(), parentNavigationModelName: String? = nil) -> NavigationModel {
        NavigationModel(id: id, path: path, selectedPath: selectedPath, parentNavigationModelId: parentNavigationModelId, parentNavigationModelName: parentNavigationModelName ?? tab?.name, tab: tab, presentedPaths: [selectedPath], isPresented: false)
    }
}
