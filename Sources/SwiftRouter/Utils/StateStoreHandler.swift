import Foundation

public extension SwiftRouter {
    struct StateStoreHandler {
        public init(
            userDefaults: UserDefaultsProvider = UserDefaults.standard,
            bundleIdentifier: String?,
            versionNumber: String?,
            buildNumber: String?,
            logger: SwiftRouter.Logger? = nil
        ) {
            self.userDefaults = userDefaults
            self.logger = logger
            let bundleIdentifier = bundleIdentifier ?? ""
            let versionNumber = versionNumber ?? "\(Int.random(in: 1_234_322_000 ... 1_000_000_000_000))"
            let buildNumber = buildNumber ?? ""
            stateIdentifier = "navigation_state_\(bundleIdentifier)_\(versionNumber)_\(buildNumber)".replacingOccurrences(of: " ", with: "_")
        }

        private let userDefaults: UserDefaultsProvider
        private let stateIdentifier: String
        private let logger: SwiftRouter.Logger?
        public static let dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    }
}

public extension SwiftRouter.StateStoreHandler {
    @MainActor func restoreRouter(
        initState: SwiftRouter.State,
        minutesThreshold: Int,
        file: StaticString = #file, line: UInt = #line
    ) -> SwiftRouter.Router? {
        do {
            let savedState = try loadFromDisk()

            // Don't load states that are older than the minutesThreshold.
            if savedState.observed.lastModified.isDate(olderThan: minutesThreshold) {
                throw StateStoreHandlerError.outdated
            }
            invalidate()

            let oldModels = savedState.observed.navigationModels.filter { !$0.isPresented }

            let navigationModels = [
                initState.observed.navigationModels
                    .filter { !$0.isPresented }
                    .map { newModel in
                        guard
                            let oldModel = oldModels.first(where: { $0.stringIdentifier == newModel.stringIdentifier })
                        else {
                            return newModel
                        }
                        return oldModel.clone(newID: newModel.id, newRoutes: newModel.routes)
                    },
                savedState.observed.navigationModels.filter { $0.isPresented },
            ].flatMap { $0 }

            guard
                let oldSelectedModel = savedState.observed.navigationModels.first(where: { $0.id == savedState.observed.selectedModelId }),
                let oldRootSelectedModel = savedState.observed.navigationModels.first(where: { $0.id == savedState.observed.rootSelectedModelID }),
                let selectedModel =
                navigationModels.first(where: { $0.stringIdentifier == oldSelectedModel.stringIdentifier }),
                let rootSelectedModel = navigationModels.first(where: { $0.stringIdentifier == oldRootSelectedModel.stringIdentifier })
            else {
                throw StateStoreHandlerError.selectedModelMismatch
            }

            logger?.info("Saved state loaded from key \(stateIdentifier)")

            return SwiftRouter.RouterImpl(
                initState: SwiftRouter.State(
                    observed: .init(
                        navigationModels: navigationModels,
                        availableRoutes: initState.observed.availableRoutes,
                        selectedModelId: selectedModel.id,
                        selectedRootModelId: rootSelectedModel.id
                    )
                )
            )

        } catch {
            logger?.info("❌ Failed to load state with error:", error)
            invalidate()
            return nil
        }
    }

    func saveToDisk(state: SwiftRouter.State, file: StaticString = #file, line: UInt = #line) {
        logger?.info("Saving navigation state", file: file, line: line)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .deferredToDate
            try userDefaults.set(
                encoder.encode(state),
                forKey: stateIdentifier
            )
            logger?.info("Navigation state saved to key \(stateIdentifier)")
        } catch {
            logger?.warning("Failed to save navigation state with error", error)
        }
    }

    func invalidate(file: StaticString = #file, line: UInt = #line) {
        userDefaults.removeObject(forKey: stateIdentifier)
        userDefaults.set("", forKey: stateIdentifier)
        logger?.debug("🗑️ Stored state has been removed", file: file, line: line)
    }

    enum StateStoreHandlerError: Error {
        case notFound
        case outdated
        case selectedModelMismatch
    }
}

private extension SwiftRouter.StateStoreHandler {
    func loadFromDisk() throws -> SwiftRouter.State {
        let data = try loadData()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let state = try decoder.decode(SwiftRouter.State.self, from: data)
        return state
    }

    func loadData() throws -> Data {
        guard
            let data = userDefaults.data(forKey: stateIdentifier)
        else {
            throw StateStoreHandlerError.notFound
        }
        return data
    }
}

private extension Date {
    func minutes(to date: Date) -> Int? {
        Calendar(identifier: .gregorian).dateComponents(
            [.minute],
            from: self,
            to: date
        ).minute
    }

    func isDate(olderThan limit: Int) -> Bool {
        (minutes(to: Date()) ?? limit) >= limit
    }
}
