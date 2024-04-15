import Foundation

public enum Navigation {
    public struct State: Sendable, Codable {
        public init(observed: Navigation.ObservedState = .init()) {
            self.observed = observed
        }

        public var observed: ObservedState
    }

    public struct ObservedState: Sendable, Equatable, Codable {
        public init(navigationModels: [NavigationModel] = [NavigationModel](), alerts: [AlertModel] = [], availableNavigationModelRoutes: [NavigationRoute] = [], availableRoutes: [NavigationRoute] = []) {
            self.availableNavigationModelRoutes = availableNavigationModelRoutes
            self.availableRoutes = availableRoutes
            self.alerts = alerts

            self.navigationModels = navigationModels.map { navigationModel in
                var navigationModel = navigationModel
                navigationModel.isPresented = false
                return navigationModel
            }

            let first = navigationModels.first?.id ?? UUID()
            selectedModelId = first
            rootSelectedModelID = first
        }

        /// Active navigationModel. It can only be one sessin at the time
        public var selectedModelId: UUID
        public var rootSelectedModelID: UUID
        public var navigationModels = [NavigationModel]()
        public var alerts: [AlertModel] = []
        public var availableNavigationModelRoutes: [NavigationRoute]
        public var availableRoutes: [NavigationRoute] = []
        public var lastModifiedID: UUID = .init()
    }
}

public extension Navigation.State {
    @MainActor static func reducer<Action>(action: Action, state: Navigation.State) -> Navigation.State {
        var state = state
        if action is NavigationAction {
            state.observed.lastModifiedID = UUID()
        }

        switch action as? NavigationAction {
        case let .multiAction(actions):
            for action in actions {
                switch action {
                case .multiAction:
                    continue
                default:
                    state = reducer(action: action, state: state)
                }
            }

        case let .setAvailableRoutes(routes):
            state.observed.availableRoutes = routes
        case let .setAvailableNavigationModelRoutes(routes):
            state.observed.availableNavigationModelRoutes = routes

        case let .setBadgeValue(to: badgeValue, withModelID: navigationModelID, withColor: color):
            guard
                let navigationModelIndex = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModelID }),
                var tab = state.observed.navigationModels.first(where: { $0.id == navigationModelID })?.tab
            else {
                return state
            }
            tab.badgeValue = badgeValue
            #if canImport(UIKit)
                if let color = color {
                    tab.badgeColor = color
                }
            #endif
            state.observed.navigationModels[navigationModelIndex].tab = tab

        case let .setIcon(to: iconName, withModelID: navigationModelID):
            guard let navigationModelIndex = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModelID })
            else {
                return state
            }
            state.observed.navigationModels[navigationModelIndex].tab?.icon = .system(name: iconName)

        case let .setSelectedPath(to: navigationPath, in: navigationModel):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }) {
                state.observed.navigationModels[index].selectedPath = navigationPath
                if state.observed.navigationModels[index].animate {
                    state.observed.navigationModels[index].animate = true
                }
                state.observed.selectedModelId = state.observed.navigationModels[index].id

                if !navigationModel.isPresented {
                    state.observed.rootSelectedModelID = navigationModel.id
                }

                // Remove all indexes that comes after current path
                state = Self.removeRedundantPaths(at: index, from: state)
            }

        case let .prepareAndDismiss(navigationModel, animated, completionAction):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.tab == nil && $0.id == navigationModel.id }) {
                var model = state.observed.navigationModels[index]
                model.animate = animated
                model.dismissCompletionAction = completionAction
                model.shouldBeDismsised = true
                state.observed.navigationModels[index] = model
            }

        case let .dismiss(navigationModel):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.isPresented && $0.id == navigationModel.id }) {
                state.observed.navigationModels.remove(at: index)

                if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                    state.observed.selectedModelId = lastPresentedModel.id
                } else {
                    state.observed.selectedModelId = state.observed.rootSelectedModelID
                }
            }

        case let .dismissPath(navigationPath):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.presentedPaths.map { $0.id }.contains(navigationPath.id) }) {
                // Close presented model if no more paths are presented
                if state.observed.navigationModels[index].isPresented, state.observed.navigationModels[index].presentedPaths.count == 1 {
                    state.observed.navigationModels.remove(at: index)

                    if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                        state.observed.selectedModelId = lastPresentedModel.id
                    } else {
                        state.observed.selectedModelId = state.observed.rootSelectedModelID
                    }
                    return state
                }

                // We cannot remove the root controller of the navigationController
                guard state.observed.navigationModels[index].presentedPaths.count > 0 else {
                    return state
                }

                if let pathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == navigationPath.id }), pathIndex - 1 >= 0 {
                    let nextPath = state.observed.navigationModels[index].presentedPaths[pathIndex - 1]
                    state.observed.navigationModels[index].selectedPath = nextPath
                    if state.observed.navigationModels[index].animate {
                        state.observed.navigationModels[index].animate = true
                    }
                    state.observed.selectedModelId = state.observed.navigationModels[index].id

                    if !state.observed.navigationModels[index].isPresented {
                        state.observed.rootSelectedModelID = state.observed.navigationModels[index].id
                    }

                    // Remove all indexes that comes after current path
                    state = Self.removeRedundantPaths(at: index, from: state)
                }
            }

        case let .add(path: navigationPath, to: target):
            guard
                let navigationPath = navigationPath,
                let url = navigationPath.url, URLMatcher().match(url, from: state.observed.availableRoutes.map { $0.path }) != nil
            else {
                print("⚠️ Cannot add \(navigationPath?.path ?? navigationPath?.id.uuidString ?? "nil") since it not supported by any route")
                return state
            }
            switch target {
            case let .current(animate):
                guard
                    let index = state.observed.navigationModels.firstIndex(where: { $0.id == state.observed.selectedModelId })
                else {
                    assertionFailure("Cannot push a view to a navigationSession that does not exist")
                    return state
                }
                state.observed.navigationModels[index].animate = animate

            case let .navigationModel(navigationModel, animate):
                guard
                    let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
                else {
                    assertionFailure("Cannot push a view to a navigationSession that does not exist")
                    return state
                }
                state.observed.selectedModelId = state.observed.navigationModels[index].id
                if !state.observed.navigationModels[index].isPresented {
                    state.observed.rootSelectedModelID = state.observed.navigationModels[index].id
                }
                state.observed.navigationModels[index].animate = animate

            case let .new(navigationModelPath, presentationType, animate):
                if #available(iOS 16.0, *) {
                    let navigationModel = NavigationModel(
                        path: navigationModelPath,
                        selectedPath: NavigationPath(),
                        parentNavigationModelId: state.observed.selectedModelId,
                        parentNavigationModelName: state.observed.navigationModels.first(where: { $0.id == state.observed.selectedModelId })?.tab?.name ?? "presented",
                        presentationType: presentationType,
                        selectedDetentIdentifier: presentationType.selectedDetent?.detent.identifier.rawValue ?? presentationType.detentItems?.first?.detent.identifier.rawValue,
                        animate: animate
                    )
                    state.observed.navigationModels.append(navigationModel)
                    state.observed.selectedModelId = navigationModel.id
                } else {
                    let navigationModel = NavigationModel(path: navigationModelPath, selectedPath: NavigationPath(), presentationType: presentationType, animate: animate)
                    state.observed.navigationModels.append(navigationModel)
                    state.observed.selectedModelId = navigationModel.id
                }
            }
            state = Self.setSelectedPath(navigationPath, in: state)

        case let .setNavigationDismsissed(navigationModel):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.isPresented && $0.id == navigationModel.id }) {
                state.observed.navigationModels.remove(at: index)

                if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                    state.observed.selectedModelId = lastPresentedModel.id
                } else {
                    state.observed.selectedModelId = state.observed.rootSelectedModelID
                }
            }

        case let .selectTab(by: navigationModelID):
            if let navigationModel = state.observed.navigationModels.first(where: { !$0.isPresented && $0.id == navigationModelID }) {
                state.observed.rootSelectedModelID = navigationModel.id
            }

        case let .replace(path: path, with: newPath, in: navigationModel):
            guard
                let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }),
                let currentPathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == path.id })
            else {
                return state
            }

            state.observed.navigationModels[index].presentedPaths[currentPathIndex] = newPath
            state.observed.navigationModels[index].animate = false

        case let .alert(model):
            state.observed.alerts.append(model)
        case let .dismissedAlert(with: model):
            if let index = state.observed.alerts.firstIndex(where: { $0.id == model.id }) {
                state.observed.alerts.remove(at: index)
            }
        case let .selectedDetentChanged(to: identifier, in: navigationModel):
            guard let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }) else { return state }
            state.observed.navigationModels[index].selectedDetentIdentifier = identifier
        default:
            break
        }

        return state
    }

    static func setSelectedPath(_ path: NavigationPath, in state: Navigation.State) -> Navigation.State {
        var state = state
        if let index = state.observed.navigationModels.firstIndex(where: { $0.id == state.observed.selectedModelId }) {
            state = Self.removeRedundantPaths(at: index, from: state)

            state.observed.navigationModels[index].selectedPath = path
            state.observed.navigationModels[index].presentedPaths.append(path)
            state.observed.selectedModelId = state.observed.navigationModels[index].id
        }
        return state
    }

    static func removeRedundantPaths(at index: Int, from state: Navigation.State) -> Navigation.State {
        // Remove all indexes that comes after current path
        var state = state
        if let presentedPathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == state.observed.navigationModels[index].selectedPath.id }) {
            let presentedPaths = state.observed.navigationModels[index].presentedPaths

            state.observed.navigationModels[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
        }

        return state
    }
}
