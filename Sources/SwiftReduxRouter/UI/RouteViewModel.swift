import SwiftUI

@MainActor public final class RouteViewModel: ObservableObject, Sendable {
    public init(path: NavPath, navigationModel: NavigationModel) {
        self.path = path
        self.navigationModel = navigationModel
    }

    @Published public private(set) var path: NavPath

    public let navigationModel: NavigationModel
    private(set) var hasBeenShown: Bool = false
    func setPath(to path: NavPath) async {
        self.path = path
    }

    func setHasBeenShown(to newValue: Bool) {
        hasBeenShown = newValue
    }
}
