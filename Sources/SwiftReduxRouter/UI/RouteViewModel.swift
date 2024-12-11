import SwiftUI

@MainActor public final class RouteViewModel: ObservableObject, Sendable {
    init(path: NavPath, navigationModel: NavigationModel) {
        self.path = path
        self.navigationModel = navigationModel
    }

    @Published public private(set) var path: NavPath

    public let navigationModel: NavigationModel

    func setPath(to path: NavPath) async {
        self.path = path
    }
}
