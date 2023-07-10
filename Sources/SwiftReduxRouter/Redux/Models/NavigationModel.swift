import Foundation

public struct NavigationModel: Codable, Equatable, Sendable {
    public init(id: UUID = UUID(), path: NavigationPath? = nil, selectedPath: NavigationPath, tab: NavigationTab? = nil, presentedPaths: [NavigationPath] = [], isPresented: Bool = true, presentationType: PresentationType = .regular) {
        self.id = id
        self.path = path
        self.isPresented = isPresented
        self.presentationType = presentationType
        self.selectedPath = selectedPath
        self.tab = tab
        self.presentedPaths = presentedPaths
        animate = true
    }

    public static func == (lhs: NavigationModel, rhs: NavigationModel) -> Bool {
        lhs.id == rhs.id
    }

    public let id: UUID
    public let path: NavigationPath?
    public var selectedPath: NavigationPath

    public var tab: NavigationTab?
    public var presentedPaths = [NavigationPath]()
    public var isPresented: Bool
    public var presentationType: PresentationType
    var animate: Bool

    public static func createInitModel(id: UUID = UUID(), path: NavigationPath?, selectedPath: NavigationPath, tab: NavigationTab? = nil) -> NavigationModel {
        NavigationModel(id: id, path: path, selectedPath: selectedPath, tab: tab, presentedPaths: [selectedPath], isPresented: false)
    }
}
