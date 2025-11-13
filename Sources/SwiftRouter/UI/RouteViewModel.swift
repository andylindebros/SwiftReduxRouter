import SwiftUI

public extension SwiftRouter {
    @MainActor final class RouteViewModel: ObservableObject, Sendable {
        public init(path: Path, navigationModel: SwiftRouter.Model) {
            self.path = path
            self.navigationModel = navigationModel
        }

        @Published public private(set) var path: Path
        public private(set) var navigationModel: SwiftRouter.Model

        private(set) var hasBeenShown: Bool = false

        func setModel(to newValue: SwiftRouter.Model) {
            navigationModel = newValue
        }

        func setPath(to path: Path) async {
            self.path = path
        }

        func setHasBeenShown(to newValue: Bool) {
            hasBeenShown = newValue
        }

        public var isSelected: Bool {
            path.id == navigationModel.selectedPath.id
        }
    }
}

public extension SwiftRouter.RouteViewModel {
    func dismissAction(animated: Bool = true, withCompletion completion: SwiftRouter.CodableClosure? = nil) -> SwiftRouter.Action {
        .dismiss(dismissTarget(animated: animated, withCompletion: completion))
    }

    func dismissTarget(animated: Bool = true, withCompletion completion: SwiftRouter.CodableClosure? = nil) -> SwiftRouter.DismissTarget {
        navigationModel.isPresented ? .model(navigationModel, animated: animated, withCompletion: completion) : .path(path, animated: animated, withCompletion: completion)
    }
}
