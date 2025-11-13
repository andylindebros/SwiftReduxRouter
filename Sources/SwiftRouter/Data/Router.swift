import Foundation
import SwiftUI

public extension SwiftRouter.Router {
    nonisolated func dispatch(_ action: SwiftRouter.Action, file: StaticString = #file, line: UInt = #line) {
        dispatch(action, file: file, line: line)
    }

    @MainActor func dispatch(_ action: SwiftRouter.Action, file: StaticString = #file, line: UInt = #line) async {
        await dispatch(action, file: file, line: line)
    }

    nonisolated func dispatch(_ actions: [SwiftRouter.Action], file: StaticString = #file, line: UInt = #line) {
        dispatch(actions, file: file, line: line)
    }

    func dispatch(_ actions: [SwiftRouter.Action], file: StaticString = #file, line: UInt = #line) async {
        await dispatch(actions, file: file, line: line)
    }
}
public extension SwiftRouter {
    @MainActor protocol Router: AnyObject, Sendable {
        /**
         Dispatches an action to modify the state of the navigation

         - parameter action: The type of action to perform in order to modify the navigation state.
         */
        nonisolated func dispatch(_ action: SwiftRouter.Action, file: StaticString, line: UInt)

        /**
         Dispatches an action to modify the state of the navigation

         - parameter action: The type of action to perform in order to modify the navigation state.
         */
        func dispatch(_ action: SwiftRouter.Action, file: StaticString, line: UInt) async

        /**
         Dispatches multiple actions at once

         - parameter action: The type of action to perform in order to modify the navigation state.
         */
        nonisolated func dispatch(_ actions: [SwiftRouter.Action], file: StaticString, line: UInt)

        /**
         Dispatches multiple actions at once

         - parameter actions: A list of actions to perform in order to modify the navigation state.
         */
        func dispatch(_ actions: [SwiftRouter.Action], file: StaticString, line: UInt) async
        /**
         The state of the navigation
         */
        var state: SwiftRouter.State { get }
    }

    @MainActor final class RouterImpl: ObservableObject, Router {
        public init(initState: SwiftRouter.State, logger: SwiftRouter.Logger? = nil) {
            state = initState
            self.logger = logger
            logState(prefixString: "👊 Init")
        }

        @Published public private(set) var observedState: UUID = .init()

        let logger: SwiftRouter.Logger?

        public private(set) var state: SwiftRouter.State { didSet {
            logState(prefixString: "👉 New")
        }}

        /**
         Dispatches an action to modify the state of the navigation

         - parameter action: The type of action to perform in order to modify the navigation state.
         */
        public nonisolated func dispatch(_ action: SwiftRouter.Action, file: StaticString = #file, line: UInt = #line) {
            Task { [weak self] in
                await self?.dispatch(action, file: file, line: line)
            }
        }

        /**
         Dispatches an action to modify the state of the navigation

         - parameter action: The type of action to perform in order to modify the navigation state.
         */
        public func dispatch(_ action: SwiftRouter.Action, file: StaticString = #file, line: UInt = #line) async {
            logger?.debug("⚡️", action, file: file, line: line)

            await setState(SwiftRouter.State.reducer(action: action, state: state))
        }

        /**
         Dispatches multiple actions at once

         - parameter actions: A list of actions to perform in order to modify the navigation state.
         */
        public func dispatch(_ actions: [SwiftRouter.Action], file: StaticString = #file, line: UInt = #line) {
            Task { [weak self] in
                await self?.dispatch(actions, file: file, line: line)
            }
        }

        /**
         Dispatches multiple actions at once

         - parameter actions: A list of actions to perform in order to modify the navigation state.
         */
        public func dispatch(_ actions: [SwiftRouter.Action], file: StaticString = #file, line: UInt = #line) async {
            logger?.debug("⚡️ Multi Actions", actions, file: file, line: line)
            await setState(SwiftRouter.State.reducer(action: SwiftRouter.Action.multiAction(actions), state: state))
        }

        private func setState(_ newState: SwiftRouter.State) async {
            let oldState = state
            state = newState

            if oldState.observed != newState.observed {
                observedState = UUID()
            }
        }

        private func logState(prefixString: String) {
            var strings = [String]()
            strings.append("\(prefixString) navigation state")
            for model in state.observed.navigationModels {
                strings.append("\(model.tab?.name ?? model.id.uuidString)")
                for path in model.presentedPaths {
                    strings.append("   - \(path.id == model.selectedPath.id && model.id == state.observed.selectedModelId ? "👀" : "") \(path.url?.absoluteString ?? "unknown")")
                }
            }
            logger?.debug(strings.joined(separator: "\n"))
        }
    }
}
