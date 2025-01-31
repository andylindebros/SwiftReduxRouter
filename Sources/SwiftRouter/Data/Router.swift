import Foundation
import OSLog
import SwiftUI

@MainActor public protocol Router: Sendable {
    /**
     Dispatches an action to modify the state of the navigation

     - parameter action: The type of action to perform in order to modify the navigation state.
     */
    nonisolated func dispatch(_ action: Navigation.Action)

    /**
     Dispatches an action to modify the state of the navigation

     - parameter action: The type of action to perform in order to modify the navigation state.
     */
    func dispatch(_ action: Navigation.Action) async

    /**
     Dispatches multiple actions at once

     - parameter action: The type of action to perform in order to modify the navigation state.
     */
    nonisolated func dispatch(_ actions: [Navigation.Action])

    /**
     Dispatches multiple actions at once

     - parameter actions: A list of actions to perform in order to modify the navigation state.
     */
    func dispatch(_ actions: [Navigation.Action]) async
    /**
     The state of the navigation
     */
    var state: Navigation.State { get }
}

@MainActor public final class RouterImpl: ObservableObject, Router {
    public init(initState: Navigation.State) {
        state = initState
    }

    @Published public private(set) var observedState: UUID = .init()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Router")

    private func debug(_ items: Any...) {
        let message = items.map { "\($0)" }.joined(separator: " ")
        Self.logger.debug("\(message)")
    }

    public private(set) var state: Navigation.State { didSet {
        var strings = [String]()
        strings.append("👉 New navigation state")
        for model in state.observed.navigationModels {
            strings.append("🧭 \(model.tab?.name ?? model.id.uuidString)")
            for path in model.presentedPaths {
                strings.append("   - \(path.id == model.selectedPath.id && model.id == state.observed.selectedModelId ? "👀" : "") \(path.url?.absoluteString ?? "unknown")")
            }
        }
        debug(strings.joined(separator: "\n"))
    }}

    /**
     Dispatches an action to modify the state of the navigation

     - parameter action: The type of action to perform in order to modify the navigation state.
     */
    public nonisolated func dispatch(_ action: Navigation.Action) {
        Task { [weak self] in
            await self?.dispatch(action)
        }
    }

    /**
     Dispatches an action to modify the state of the navigation

     - parameter action: The type of action to perform in order to modify the navigation state.
     */
    public func dispatch(_ action: Navigation.Action) async {
        debug("⚽️⚡️", action)

        await setState(Navigation.State.reducer(action: action, state: state))
    }

    /**
     Dispatches multiple actions at once

     - parameter actions: A list of actions to perform in order to modify the navigation state.
     */
    public func dispatch(_ actions: [Navigation.Action]) {
        Task { [weak self] in
            await self?.dispatch(actions)
        }
    }

    /**
     Dispatches multiple actions at once

     - parameter actions: A list of actions to perform in order to modify the navigation state.
     */
    public func dispatch(_ actions: [Navigation.Action]) async {
        await setState(Navigation.State.reducer(action: Navigation.Action.multiAction(actions), state: state))
    }

    private func setState(_ newState: Navigation.State) async {
        let oldState = state
        state = newState

        if oldState.observed != newState.observed {
            observedState = UUID()
        }
    }
}
