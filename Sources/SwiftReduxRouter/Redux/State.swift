import Foundation

// MARK: State

public final class NavigationState: ObservableObject, Codable {
    // MARK: Published vars

    /// Active navigationModel. It can only be one sessin at the time
    @Published public private(set) var selectedModelId: UUID
    @Published public private(set) var rootSelectedModelID: UUID

    /// Available navigationModels. Tab navigationModels are defined here.
    @Published public private(set) var navigationModels = [NavigationModel]()

    public init(navigationModels: [NavigationModel]? = nil) {
        selectedModelId = UUID()
        rootSelectedModelID = UUID()
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
    }

    enum CodingKeys: CodingKey {
        case selectedModelId, navigationModels, rootSelectedModelID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(navigationModels, forKey: .navigationModels)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encode(rootSelectedModelID, forKey: .rootSelectedModelID)
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

// MARK: Reducer

public extension NavigationState {
    @MainActor static func reducer<Action>(action: Action, state: NavigationState?) -> NavigationState {
        let state = state ?? NavigationState()

        switch action {
        case let a as NavigationActions.SetBadgeValue:
            guard
                let navigationModelIndex = state.navigationModels.firstIndex(where: { $0.id == a.navigationModelID }),
                var tab = state.navigationModels.first(where: { $0.id == a.navigationModelID })?.tab
            else {
                return state
            }
            tab.badgeValue = a.badgeValue
            if let color = a.color {
                tab.badgeColor = color
            }
            state.navigationModels[navigationModelIndex].tab = tab

        case let a as NavigationActions.UpdateIcon:
            guard let navigationModelIndex = state.navigationModels.firstIndex(where: { $0.id == a.navigationModelID })
            else {
                return state
            }
            state.navigationModels[navigationModelIndex].tab?.icon = .system(name: a.iconName)

        case let a as NavigationJumpStateAction:
            state.navigationModels = a.navigationState.navigationModels
            state.selectedModelId = a.navigationState.selectedModelId
            state.rootSelectedModelID = a.navigationState.rootSelectedModelID

        case let a as NavigationActions.SetSelectedPath:
            if let index = state.navigationModels.firstIndex(where: { $0.id == a.navigationModel.id }) {
                state.navigationModels[index].selectedPath = a.navigationPath
                if state.navigationModels[index].animate {
                    state.navigationModels[index].animate = true
                }
                state.selectedModelId = state.navigationModels[index].id

                if !a.navigationModel.isPresented {
                    state.rootSelectedModelID = a.navigationModel.id
                }

                // Remove all indexes that comes after current path
                state.removeRedundantPaths(at: index)
            }

        case let a as NavigationActions.Dismiss:
            if let index = state.navigationModels.firstIndex(where: { $0.isPresented && $0.id == a.navigationModel.id }) {
                state.navigationModels.remove(at: index)

                if let lastPresentedModel = state.navigationModels.last(where: { $0.isPresented }) {
                    state.selectedModelId = lastPresentedModel.id
                } else {
                    state.selectedModelId = state.rootSelectedModelID
                }
            }

        case let a as NavigationActions.Push:
            switch a.target {
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
                state.navigationModels[index].animate = animate

            case let .new(modelName, _):
                let navigationModel = NavigationModel(name: modelName, selectedPath: NavigationPath(""))
                state.navigationModels.append(navigationModel)
                state.selectedModelId = navigationModel.id
            }
            state.setSelectedPath(a.path)

        case let a as NavigationActions.Present:
            let navigationModel = NavigationModel(name: UUID().uuidString, selectedPath: NavigationPath(""))
            state.navigationModels.append(navigationModel)
            state.selectedModelId = navigationModel.id
            state.setSelectedPath(a.path)

        case let a as NavigationActions.NavigationDismissed:
            if let index = state.navigationModels.firstIndex(where: { $0.isPresented && $0.id == a.navigationModel.id }) {
                state.navigationModels.remove(at: index)

                if let lastPresentedModel = state.navigationModels.last(where: { $0.isPresented }) {
                    state.selectedModelId = lastPresentedModel.id
                } else {
                    state.selectedModelId = state.rootSelectedModelID
                }
            }

        case let a as NavigationActions.SelectTab:
            if let navigationModel = state.navigationModels.first(where: { !$0.isPresented && $0.id == a.id }) {
                state.rootSelectedModelID = navigationModel.id
            }

        case let a as NavigationActions.Replace:
            guard
                let index = state.navigationModels.firstIndex(where: { $0.id == a.navigationModel.id }),
                let currentPathIndex = state.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == a.path.id })
            else {
                return state
            }

            state.navigationModels[index].presentedPaths[currentPathIndex] = a.newPath
            state.navigationModels[index].animate = false

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
