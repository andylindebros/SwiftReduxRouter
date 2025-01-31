import SwiftUI

public extension Navigation {
    @MainActor final class RouteViewModel: ObservableObject, Sendable {
        public init(path: Path, navigationModel: Navigation.Model) {
            self.path = path
            self.navigationModel = navigationModel
        }

        @Published public private(set) var path: Path

        public let navigationModel: Navigation.Model
        private(set) var hasBeenShown: Bool = false
        func setPath(to path: Path) async {
            self.path = path
        }

        func setHasBeenShown(to newValue: Bool) {
            hasBeenShown = newValue
        }
    }
}
