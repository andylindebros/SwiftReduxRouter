import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

// swiftlint:disable opening_brace
public extension SwiftRouter {
    struct State: Sendable, Equatable, Codable {
        public init(observed: SwiftRouter.ObservedState = .init()) {
            self.observed = observed
        }

        public var observed: ObservedState
    }

    struct ObservedState: Sendable, Equatable, Codable {
        public init(navigationModels: [Model] = [Model](), alerts: [AlertModel] = [], availableRoutes: [Route] = [], selectedModelId: UUID? = nil, selectedRootModelId: UUID? = nil, lastModified: Date = .now) {
            self.availableRoutes = availableRoutes
            self.alerts = alerts

            self.navigationModels = navigationModels
            self.lastModified = lastModified

            let first = navigationModels.first?.id ?? UUID()
            self.selectedModelId = selectedModelId ?? first
            rootSelectedModelID = selectedRootModelId ?? first
        }

        /// Active navigationModel. It can only be one session at the time
        public var selectedModelId: UUID
        public var rootSelectedModelID: UUID
        public var navigationModels = [Model]()
        public var alerts: [AlertModel] = []
        public var availableRoutes: [Route] = []
        public var lastModified: Date = Date.now
        public var tipIdentifier: String?
        public var tipNavigationModelID: UUID?
        public var removeUntrackedViews: Bool = false
        public var dismissAllCompletion: CodableClosure?
    }
}

public extension SwiftRouter.State {
    // swiftlint:disable cyclomatic_complexity function_body_length

    /**
     The reducer changes the input state and returns a new state based on the action

     - parameter action: The type of action to perform in order to modify the state.
     - parameter state: The state to modify
     - returns: A new modified state
     */
    static func reducer<Action>(action: Action, state: SwiftRouter.State) -> SwiftRouter.State {
        var state = state
        guard let action = action as? SwiftRouter.Action else { return state }

        state.observed.lastModified = .now

        switch action {
        case let .multiAction(actions):
            for action in actions {
                state = reducer(action: action, state: state)
            }

        case let .setAvailableRoutes(routes):
            state.observed.availableRoutes = routes

        case let .setBadgeValue(to: badgeValue, withModelID: navigationModelID, withColor: color):
            guard
                let navigationModelIndex = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModelID }),
                var tab = state.observed.navigationModels.first(where: { $0.id == navigationModelID })?.tab
            else {
                return state
            }
            tab.badgeValue = badgeValue

            if let color = color {
                tab.badgeColor = color
            }

            state.observed.navigationModels[navigationModelIndex].tab = tab

        case let .setSelectedPath(to: navPath, in: navigationModel):
            if let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }) {
                state.observed.navigationModels[index].selectedPath = navPath

                if let pathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == navPath.id }) {
                    state.observed.navigationModels[index].presentedPaths[pathIndex].hasBeenShown = true
                }

                if !state.observed.navigationModels[index].animate {
                    state.observed.navigationModels[index].animate = true
                }
                state.observed.selectedModelId = state.observed.navigationModels[index].id

                if !navigationModel.isPresented {
                    state.observed.rootSelectedModelID = navigationModel.id
                }

                // Remove all indexes that comes after current path
                state = Self.removeRedundantPaths(at: index, from: state)
            }

        case let .dismiss(dismissTarget):
            switch dismissTarget {
            case let .popToRoot(byModelId: modelId):
                guard
                    let index = state.observed.navigationModels.firstIndex(where: { $0.id == modelId }),
                    let selectedPath = state.observed.navigationModels[index].presentedPaths.first
                else {
                    print("Cannot pop top root since the model or the root path does not exist", dismissTarget)
                    return state
                }
                state.observed.navigationModels[index].selectedPath = selectedPath
                state = Self.removeRedundantPaths(at: index, from: state)

            case let .currentModel(animated, completion):
                if let index = state.observed.navigationModels.firstIndex(where: { $0.isPresented && $0.id == state.observed.selectedModelId }) {
                    if let completion {
                        var model = state.observed.navigationModels[index]
                        model.animate = animated
                        model.dismissCompletionAction = completion
                        model.shouldBeDismsised = true
                        state.observed.navigationModels[index] = model

                    } else {
                        state.observed.navigationModels.remove(at: index)
                        if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                            state.observed.selectedModelId = lastPresentedModel.id
                        } else {
                            state.observed.selectedModelId = state.observed.rootSelectedModelID
                        }
                    }
                }

            case let .model(navigationModel, animated, completion):
                if let index = state.observed.navigationModels.firstIndex(where: { $0.isPresented && $0.id == navigationModel.id }) {
                    if let completion {
                        var model = state.observed.navigationModels[index]
                        model.animate = animated
                        model.dismissCompletionAction = completion
                        model.shouldBeDismsised = true
                        state.observed.navigationModels[index] = model
                    } else {
                        state.observed.navigationModels.remove(at: index)

                        if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                            state.observed.selectedModelId = lastPresentedModel.id
                        } else {
                            state.observed.selectedModelId = state.observed.rootSelectedModelID
                        }
                    }
                }

            case let .currentPath(animated):
                guard
                    let model = state.observed.navigationModels.first(where: { $0.id == state.observed.selectedModelId }),
                    let modelIndex = state.observed.navigationModels.firstIndex(where: { $0.id == state.observed.selectedModelId }),
                    model.presentedPaths.count > 1,
                    let deletionPathIndex = model.presentedPaths.firstIndex(where: { $0.id == model.selectedPath.id })
                else {
                    print("⚠️ Cannot pop current path since it does not exist or it is the root path of the navigation model")
                    return state
                }

                state.observed.navigationModels[modelIndex].animate = animated
                state.observed.navigationModels[modelIndex].presentedPaths = model.presentedPaths.filter({ $0.id != model.selectedPath.id })
                state.observed.navigationModels[modelIndex].selectedPath = model.presentedPaths[deletionPathIndex - 1]

                // Remove all indexes that comes after current path
                state = Self.removeRedundantPaths(at: modelIndex, from: state)

            case let .path(navPath, animated, completion):
                if let index = state.observed.navigationModels.firstIndex(where: { $0.presentedPaths.map { $0.id }.contains(navPath.id) }) {
                    // Close presented model if no more paths are presented
                    if state.observed.navigationModels[index].isPresented, state.observed.navigationModels[index].presentedPaths.count == 1 {
                        if let completion {
                            var model = state.observed.navigationModels[index]
                            model.animate = animated
                            model.dismissCompletionAction = completion
                            model.shouldBeDismsised = true
                            state.observed.navigationModels[index] = model
                        } else {
                            state.observed.navigationModels.remove(at: index)

                            if let lastPresentedModel = state.observed.navigationModels.last(where: { $0.isPresented }) {
                                state.observed.selectedModelId = lastPresentedModel.id
                            } else {
                                state.observed.selectedModelId = state.observed.rootSelectedModelID
                            }
                        }
                        return state
                    }

                    // We cannot remove the root controller of the navigationController
                    guard state.observed.navigationModels[index].presentedPaths.count > 0 else {
                        return state
                    }

                    if let pathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == navPath.id }), pathIndex - 1 >= 0 {
                        let nextPath = state.observed.navigationModels[index].presentedPaths[pathIndex - 1]
                        state.observed.navigationModels[index].selectedPath = nextPath
                        if !state.observed.navigationModels[index].animate {
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

            case let .allPresented(includingUntracked, completionAction):
                state.observed.navigationModels = state.observed.navigationModels.filter { !$0.isPresented }
                state.observed.selectedModelId = state.observed.rootSelectedModelID
                state.observed.removeUntrackedViews = includingUntracked
                state.observed.alerts = []
                state.observed.dismissAllCompletion = completionAction
            }

        case .untrackedViewsRemoved:
            state.observed.removeUntrackedViews = false
            state.observed.dismissAllCompletion?.completion?()
            state.observed.dismissAllCompletion = nil

        case let .update(path, withURL: url, in: navigationModel, withHapticFeedback: hapticFeedback):
            guard
                let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }),
                let currentPathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == path.id }),
                let currentPath = state.observed.navigationModels[index].presentedPaths.first(where: { $0.id == path.id }),
                let currentPathURLMatchResult = currentPath.urlMatchResult(of: state.observed.availableRoutes),
                let route = Self.route(by: currentPathURLMatchResult, in: state.observed.availableRoutes),
                let matchResult = URLMatcher().match(url?.path ?? "uknown", from: [route.pattern]),
                route.validate(result: matchResult, forAccessLevel: .private)
            else {
                print(
                    "Cannot update path \(path) since it does not support \(url?.absoluteString ?? "unknown")"
                )
                return state
            }

            let path = SwiftRouter.Path(
                id: currentPath.id,
                url,
                path.name,
                matchResult,
                hasBeenShown: currentPath.hasBeenShown
            )

            state.observed.navigationModels[index].presentedPaths[currentPathIndex] = path
            state.observed.navigationModels[index].animate = false
            state = Self.reducer(action: SwiftRouter.Action.setSelectedPath(to: path, in: state.observed.navigationModels[index]), state: state)

            if hapticFeedback {
                impactOccured()
            }

        case let .open(path: navigationPath, in: target, withHapticFeedback: hapticFeedback):
            guard let navigationPath = Self.validate(path: navigationPath, in: state) else {
                return state
            }

            switch target {
            case let .current(animate):
                guard
                    let index = state.observed.navigationModels.firstIndex(where: { $0.id == state.observed.selectedModelId })
                else {
                    let meesage = "Cannot push a view to a navigationModel that does not exist"
                    print(meesage, "state.observed.selectedModelId", state.observed.selectedModelId, "desired path", navigationPath, "target: .current()")
                    assertionFailure(meesage)
                    return state
                }
                state.observed.navigationModels[index].animate = animate

                state = Self.updateOrOpen(navigationPath, with: state.observed.navigationModels[index], in: state)

            case let .modelId(id, animate):
                guard
                    let model = state.observed.navigationModels.first(where: { $0.id == id })
                else {
                    let message = "Cannot open a view in a navigationModel that does not exist"
                    print(message, "state.observed.selectedModelId", state.observed.selectedModelId, "desired path", navigationPath, "target: .modelId(\(id)")
                    return state
                }
                return Self.reducer(action: SwiftRouter.Action.open(path: navigationPath, in: .model(model, animate: animate), withHapticFeedback: hapticFeedback), state: state)

            case let .model(navigationModel, animate):
                guard
                    let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
                else {
                    let message = "Cannot push a view to a navigationModel that does not exist"
                    print(message, "state.observed.selectedModelId", state.observed.selectedModelId, "desired path", navigationPath, "target: .model(\(navigationModel)")
                    return state
                }
                state.observed.selectedModelId = state.observed.navigationModels[index].id
                if !state.observed.navigationModels[index].isPresented {
                    state.observed.rootSelectedModelID = state.observed.navigationModels[index].id
                }
                state.observed.navigationModels[index].animate = animate

                state = Self.updateOrOpen(navigationPath, with: navigationModel, in: state)

            case let .new(routes, presentationType):
                let navigationModel = SwiftRouter.Model(
                    routes: routes,
                    selectedPath: SwiftRouter.Path(),
                    presentationType: presentationType,
                    selectedDetentIdentifier: presentationType.selectedDetent?.identifier ?? presentationType.detentItems?.first?.identifier,
                    animate: presentationType.options.animated
                )
                state.observed.navigationModels.append(navigationModel)
                state.observed.selectedModelId = navigationModel.id

                state = Self.setSelectedPath(navigationPath, in: state)
            }
            if hapticFeedback {
                impactOccured()
            }

        case let .setNavigationDismissed(navigationModel):
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
                state.observed.selectedModelId = navigationModel.id
                state.observed.rootSelectedModelID = navigationModel.id
            }

        case let .replace(path: path, with: newPath, in: navigationModel):
            guard
                let newPath = Self.validate(path: newPath, in: state),
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

        case let .selectedDetentIdentifierChanged(to: identifier, in: navigationModel):
            guard let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id }) else { return state }
            state.observed.navigationModels[index].selectedDetentIdentifier = identifier

        case let .setNewDetents(detents, selected, in: navigationModel, largestUndimmedDetentIdentifier, prefersGrabberVisible, preferredCornerRadius, prefersScrollingExpandsWhenScrolledToEdge):
            guard
                let index = state.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id && $0.isPresented }),
                detents.contains(selected),
                detents.count > 0,
                let model = state.observed.navigationModels.first(where: { $0.id == navigationModel.id })
            else {
                print("Failed to set new detents to \(navigationModel). Desired navigationModel was not found or is not presented or the newDetents are invalid. Amount of detents needs to be at least one")
                return state
            }

            var detentsModel = SwiftRouter.Model.PresentationType.DetentOptionsModel(detents: detents, selected: selected, largestUndimmedDetentIdentifier: largestUndimmedDetentIdentifier, prefersGrabberVisible: prefersGrabberVisible, preferredCornerRadius: preferredCornerRadius, prefersScrollingExpandsWhenScrolledToEdge: prefersScrollingExpandsWhenScrolledToEdge)
            var options = SwiftRouter.Model.PresentationType.TransitionOptions()
            if case SwiftRouter.Model.PresentationType.detents(let detentsModelOld, let optionsOld) = model.presentationType {
                detentsModel = detentsModelOld
                detentsModel.detents = detents
                detentsModel.selected = selected
                options = optionsOld
            }

            state.observed.navigationModels[index].presentationType = .detents(detentsModel, options: options)
            state.observed.navigationModels[index].selectedDetentIdentifier = selected.identifier

        case let .setTabTipIdentifier(identifier, byNavigationModel: navigationModel):
            guard
                state.observed.navigationModels.map({ $0.id }).contains(navigationModel.id)
            else {
                return state
            }
            state.observed.tipIdentifier = identifier
            state.observed.tipNavigationModelID = identifier != nil ? navigationModel.id : nil

        }

        return state
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    static func setSelectedPath(_ path: SwiftRouter.Path, in state: SwiftRouter.State) -> SwiftRouter.State {
        var state = state
        if let index = state.observed.navigationModels.firstIndex(where: { $0.id == state.observed.selectedModelId }) {
            state = Self.removeRedundantPaths(at: index, from: state)

            state.observed.navigationModels[index].selectedPath = path
            state.observed.navigationModels[index].presentedPaths.append(path)
            state.observed.selectedModelId = state.observed.navigationModels[index].id
        }
        return state
    }

    static func removeRedundantPaths(at index: Int, from state: SwiftRouter.State) -> SwiftRouter.State {
        // Remove all indexes that comes after current path
        var state = state
        if let presentedPathIndex = state.observed.navigationModels[index].presentedPaths.firstIndex(where: { $0.id == state.observed.navigationModels[index].selectedPath.id }) {
            let presentedPaths = state.observed.navigationModels[index].presentedPaths

            state.observed.navigationModels[index].presentedPaths = Array(presentedPaths[0 ... presentedPathIndex])
        }

        return state
    }
}

extension SwiftRouter.State {
    static func route(by urlMatchResult: URLMatchResult, in availableRoutes: [SwiftRouter.Route]) -> SwiftRouter.Route? {
        guard
            let route = availableRoutes.first(where: { $0.pattern == urlMatchResult.pattern })
        else {
            return nil
        }

        return route
    }

    static func validate(path navigationPath: SwiftRouter.Path?, in state: SwiftRouter.State, logger: SwiftRouter.Logger? = nil) -> SwiftRouter.Path? {
        guard
            let navigationPath,
            let urlMatchResult = navigationPath.urlMatchResult(of: state.observed.availableRoutes)
        else {
            logger?.warning(
                "Cannot open \(navigationPath?.path ?? navigationPath?.id.uuidString ?? "unknown") since it not supported by any route"
            )
            return nil
        }

        if let route = Self.route(by: urlMatchResult, in: state.observed.availableRoutes) {
            guard
                route.validate(result: urlMatchResult, forAccessLevel: .private)
            else {
                logger?.warning(
                    "Cannot open \(navigationPath.path ?? navigationPath.id.uuidString) since it not supported by any route"
                )
                return nil
            }
        }

        return SwiftRouter.Path(
            id: navigationPath.id,
            navigationPath.url,
            navigationPath.name,
            urlMatchResult,
            navBarOptions: navigationPath.navBarOptions
        )
    }

    static func updateOrOpen(_ navigationPath: SwiftRouter.Path, with model: SwiftRouter.Model, in state: SwiftRouter.State) -> SwiftRouter.State {
        // Exact: 100% match in a tab and duplicates are not allowed
        if
            let newURL = navigationPath.url,
            let matchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.pattern }),
            let currentPath = model.presentedPaths.first(where: { $0.path == newURL.path }),
            currentPath.path == newURL.path,
            let route = SwiftRouter.State.route(by: matchResult, in: state.observed.availableRoutes),
            route.accessLevel.grantAccess(for: .private),
            !route.allowsDuplicates
        {
            return reducer(action: SwiftRouter.Action.setSelectedPath(to: currentPath, in: model), state: state)
        }

        // Similar: URL has an similar match in a tab and duplicates are not allowed
        if
            let newURL = navigationPath.url,
            let newMatchResult = URLMatcher().match(newURL.path, from: state.observed.availableRoutes.compactMap { $0.pattern }),
            let currentPath = model.presentedPaths.first(where: { $0.urlMatchResult(of: state.observed.availableRoutes)?.pattern == newMatchResult.pattern }),
            let route = SwiftRouter.State.route(by: newMatchResult, in: state.observed.availableRoutes),
            !route.rules.isEmpty,
            !route.allowsDuplicates,
            route.validate(result: newMatchResult, forAccessLevel: .private)
        {
            return Self.reducer(action: SwiftRouter.Action.update(path: currentPath, withURL: newURL, in: model), state: state)
        }

        // Add as new
        return Self.setSelectedPath(navigationPath, in: state)
    }

    private static func impactOccured() {
        Task {
            await UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// swiftlint:enable opening_brace

