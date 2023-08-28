import Foundation

// MARK: State

public final class NavigationState: ObservableObject, Codable {
    public init(navigationModels: [NavigationModel]? = nil) {
        selectedModelId = UUID()
        rootSelectedModelID = UUID()
        availableNavigationModelRoutes = []

        if let navigationModels = navigationModels {
            self.navigationModels = navigationModels.map { navigationModel in
                var navigationModel = navigationModel
                navigationModel.isPresented = false
                return navigationModel
            }

            if let first = navigationModels.first {
                selectedModelId = first.id
                rootSelectedModelID = first.id
            }
        }
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelId = try values.decode(UUID.self, forKey: .selectedModelId)
        rootSelectedModelID = try values.decode(UUID.self, forKey: .rootSelectedModelID)
        navigationModels = try values.decode([NavigationModel].self, forKey: .navigationModels)
        availableNavigationModelRoutes = try values.decode([NavigationRoute].self, forKey: .availableNavigationModelRoutes)
        availableRoutes = try values.decode([NavigationRoute].self, forKey: .availableRoutes)
    }

    /// Active navigationModel. It can only be one sessin at the time
    @Published public private(set) var selectedModelId: UUID
    @Published public private(set) var rootSelectedModelID: UUID

    /// Available navigationModels. Tab navigationModels are defined here.
    @Published public private(set) var navigationModels = [NavigationModel]()

    @Published public private(set) var alerts: [AlertModel] = []

    public private(set) var availableNavigationModelRoutes: [NavigationRoute]

    private(set) var availableRoutes: [NavigationRoute] = []

    enum CodingKeys: CodingKey {
        case selectedModelId, navigationModels, rootSelectedModelID, availableNavigationModelRoutes, availableRoutes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(navigationModels, forKey: .navigationModels)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encode(rootSelectedModelID, forKey: .rootSelectedModelID)
        try container.encode(availableNavigationModelRoutes, forKey: .availableNavigationModelRoutes)
        try container.encode(availableRoutes, forKey: .availableRoutes)
    }
}

public extension NavigationState {
    func isTopModel(_ navigationModel: NavigationModel) -> Bool {
        guard let topModel = getTopModel() else { return false }

        return topModel.id == navigationModel.id
    }

    func getTopModel() -> NavigationModel? {
        if let presentedModel = navigationModels.first(where: { $0.isPresented && $0.id == selectedModelId }) {
            return presentedModel
        }

        if let rootModel = navigationModels.first(where: { $0.id == rootSelectedModelID }) {
            return rootModel
        }
        return nil
    }
}

extension NavigationState {
    @discardableResult func setAvailableRoutes(_ availableRoutes: [NavigationRoute]) -> Self {
        self.availableRoutes = availableRoutes
        return self
    }
    @discardableResult func setAvailableNavigationRoutes(_ availableRoutes: [NavigationRoute]) -> Self {
        self.availableNavigationModelRoutes = availableRoutes
        return self
    }
}

// MARK: Reducer

public extension NavigationState {
    @MainActor static func reducer<Action>(action: Action, state: NavigationState?) -> NavigationState {
        let state = state ?? NavigationState()

        if let action = action as? NavigationJumpStateAction {
            state.navigationModels = action.navigationState.navigationModels
            state.selectedModelId = action.navigationState.selectedModelId
            state.rootSelectedModelID = action.navigationState.rootSelectedModelID
            return state
        }

        switch action as? NavigationAction {
        case let .setBadgeValue(to: badgeValue, withModelID: navigationModelID, withColor: color):
            guard
                let navigationModelIndex = state.navigationModels.firstIndex(where: { $0.id == navigationModelID }),
                var tab = state.navigationModels.first(where: { $0.id == navigationModelID })?.tab
            else {
                return state
            }
            tab.badgeValue = badgeValue
            #if canImport(UIKit)
                if let color = color {
                    tab.badgeColor = color
                }
            #endif
            state.navigationModels[navigationModelIndex].tab = tab

        case let .setIcon(to: iconName, withModelID: navigationModelID):
            guard let navigationModelIndex = state.navigationModels.firstIndex(where: { $0.id == navigationModelID })
            else {
                return state
            }
            state.navigationModels[navigationModelIndex].tab?.icon = .system(name: iconName)

        case let .setSelectedPath(to: navigationPath, in: navigationModel):
            if let index = state.navigationModels.firstIndex(where: { $0.id == navigationModel.id }) {
                state.navigationModels[index].selectedPath = navigationPath
                if state.navigationModels[index].animate {
                    state.navigationModels[index].animate = true
                }
                state.selectedModelId = state.navigationModels[index].id

                if !navigationModel.isPresented {
                    state.rootSelectedModelID = navigationModel.id
                }

                // Remove all indexes that comes after current path
                state.removeRedundantPaths(at: index)
            }

        case let .dismiss(navigationModel):
            if let index = state.navigationModels.firstIndex(where: { $0.isPresented && $0.id == navigationModel.id }) {
                state.navigationModels.remove(at: index)

                if let lastPresentedModel = state.navigationModels.last(where: { $0.isPresented }) {
                    state.selectedModelId = lastPresentedModel.id
                } else {
                    state.selectedModelId = state.rootSelectedModelID
                }
            }

        case let .add(path: navigationPath, to: target):
            guard let url = navigationPath.url, URLMatcher().match(url, from: state.availableRoutes.map { $0.path }) != nil else {
                print("⚠️ Cannot add \(navigationPath.path ?? navigationPath.id.uuidString) since it not supported by any route")
                return state
            }
            switch target {
            case let .current(animate):
                guard
                    let index = state.navigationModels.firstIndex(where: { $0.id == state.selectedModelId })
                else {
                    assertionFailure("Cannot push a view to a navigationSession that does not exist")
                    return state
                }
                state.navigationModels[index].animate = animate

            case let .navigationModel(navigationModel, animate):
                guard
                    let index = state.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
                else {
                    assertionFailure("Cannot push a view to a navigationSession that does not exist")
                    return state
                }
                state.selectedModelId = state.navigationModels[index].id
                if !state.navigationModels[index].isPresented {
                    state.rootSelectedModelID = state.navigationModels[index].id
                }
                state.navigationModels[index].animate = animate

            case let .new(navigationModelPath, _):
                let navigationModel = NavigationModel(path: navigationModelPath, selectedPath: NavigationPath())
                state.navigationModels.append(navigationModel)
                state.selectedModelId = navigationModel.id
            }
            state.setSelectedPath(navigationPath)

        case let .setNavigationDismsissed(navigationModel):
            if let index = state.navigationModels.firstIndex(where: { $0.isPresented && $0.id == navigationModel.id }) {
                state.navigationModels.remove(at: index)

                if let lastPresentedModel = state.navigationModels.last(where: { $0.isPresented }) {
                    state.selectedModelId = lastPresentedModel.id
                } else {
                    state.selectedModelId = state.rootSelectedModelID
                }
            }

        case let .selectTab(by: navigationModelID):
            if let navigationModel = state.navigationModels.first(where: { !$0.isPresented && $0.id == navigationModelID }) {
                state.rootSelectedModelID = navigationModel.id
            }

        case let .replace(path: path, with: newPath, in: navigationModel):

            guard
                let index = state.navigationModels.firstIndex(where: { $0.id == navigationModel.id }),
                let currentPathIndex = state.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == path.id })
            else {
                return state
            }

            state.navigationModels[index].presentedPaths[currentPathIndex] = newPath
            state.navigationModels[index].animate = false

        case let .alert(model):
            state.alerts.append(model)
        case let .dismissedAlert(with: model):
            if let index = state.alerts.firstIndex(where: { $0.id == model.id }) {
                state.alerts.remove(at: index)
            }
        default:
            break
        }
        return state
    }
}

private extension NavigationState {
    func setSelectedPath(_ path: NavigationPath) {
        if let index = navigationModels.firstIndex(where: { $0.id == selectedModelId }) {
            removeRedundantPaths(at: index)

            navigationModels[index].selectedPath = path
            navigationModels[index].presentedPaths.append(path)
            selectedModelId = navigationModels[index].id
        }
    }

    func removeRedundantPaths(at index: Int) {
        // Remove all indexes that comes after current path
        if let presentedPathIndex = navigationModels[index].presentedPaths.firstIndex(where: { $0.id == navigationModels[index].selectedPath.id }) {
            let presentedPaths = navigationModels[index].presentedPaths

            navigationModels[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
        }
    }
}
