import Foundation
@testable import SwiftRouter
import Testing

@Suite(.serialized)
struct NavigationTests {
    @Test("Push a new view to current model") func testPushAction() async throws {
        let router = await generateRouter()

        let desiredPath = try #require(SwiftRouter.Path.create("/third"))

        await router.dispatch(.open(
            path: desiredPath
        ))

        let selectedModel = await router.state.observed.navigationModels.first

        #expect(await router.state.observed.navigationModels.first?.selectedPath.id == desiredPath.id)
        #expect(await router.state.observed.rootSelectedModelID == selectedModel?.id)
        #expect(await router.state.observed.selectedModelId == selectedModel?.id)

        // dismiss path should just pop it from the navigation stack since the model is implemented as a tab
        await router.dispatch(.dismiss(.path(desiredPath)))

        let newSelectedPath = try await #require(router.state.observed.navigationModels.first?.presentedPaths.first)
        #expect(await router.state.observed.rootSelectedModelID == selectedModel?.id)
        #expect(await router.state.observed.selectedModelId == selectedModel?.id)
        #expect(await router.state.observed.navigationModels.first(where: { $0.id == desiredPath.id }) == nil)
        #expect(await router.state.observed.navigationModels.first?.selectedPath == newSelectedPath)
    }

    @Test("Push a new view to desired model") func pushToSpecificModelAction() async throws {
        let router = await generateRouter()

        let desiredPath = try #require(SwiftRouter.Path.create("/third"))

        let desiredModel = try await #require(router.state.observed.navigationModels.last)

        await router.dispatch(.open(
            path: desiredPath,
            in: .model(desiredModel)
        ))

        #expect(await router.state.observed.navigationModels.last?.selectedPath.id == desiredPath.id)
        #expect(await router.state.observed.rootSelectedModelID == desiredModel.id)
        #expect(await router.state.observed.selectedModelId == desiredModel.id)

        // Dismiss model should not be possible since it is implemented as a tab.
        await router.dispatch(
            .dismiss(.model(desiredModel))
        )
        #expect(await router.state.observed.rootSelectedModelID == desiredModel.id)
        #expect(await router.state.observed.selectedModelId == desiredModel.id)
    }

    @Test("Present a new view") func testPresentAction() async throws {
        let router = await generateRouter()

        let desiredPath = try #require(SwiftRouter.Path.create("/third"))

        await router.dispatch(.open(
            path: desiredPath,
            in: .new()
        ))

        let selectedModel = try await #require(router.state.observed.navigationModels.last)

        let rootSelectedModel = try await #require(router.state.observed.navigationModels.first)
        #expect(await selectedModel.selectedPath.id == desiredPath.id)
        #expect(await router.state.observed.rootSelectedModelID == rootSelectedModel.id)
        #expect(await router.state.observed.selectedModelId == selectedModel.id)

        let secondPath = try #require(SwiftRouter.Path.create("/first"))
        // push a second path to the presentedModel
        await router.dispatch(.open(
            path: secondPath,
            in: .model(selectedModel)
        ))

        #expect(await router.state.observed.selectedModelId == selectedModel.id)
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.last?.id == secondPath.id)
        #expect(await router.state.observed.navigationModels.last?.selectedPath.id == secondPath.id)

        // Should dismiss the presented model since this path is the only presented path in the presented model
        await router.dispatch(.dismiss(.path(secondPath)))

        #expect(await router.state.observed.selectedModelId == selectedModel.id)
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.first(where: { $0.id == secondPath.id }) == nil)
        #expect(await router.state.observed.navigationModels.last?.selectedPath.id == desiredPath.id)

        await router.dispatch(.dismiss(.path(desiredPath)))

        #expect(await router.state.observed.navigationModels.first(where: { $0.id == selectedModel.id }) == nil)
        #expect(await router.state.observed.rootSelectedModelID == rootSelectedModel.id)
        #expect(await router.state.observed.selectedModelId == rootSelectedModel.id)
    }

    @Test("Open fullscreen model") func testOpenFullscreenModel() async throws {
        let router = await generateRouter()

        await router.dispatch(.open(
            path: SwiftRouter.Path.create("/third"),
            in: .new(type: .overFullScreen())
        ))

        #expect(await router.state.observed.navigationModels.last?.presentationType == .overFullScreen())
    }

    @Test("Dismiss by model") func testDismissByModel() async throws {
        let router = await generateRouter()

        let desiredPath = try #require(SwiftRouter.Path.create("/third"))

        await router.dispatch(.open(
            path: desiredPath,
            in: .new()
        ))

        let selectedModel = try await #require(router.state.observed.navigationModels.last)
        let rootSelectedModel = try await #require(router.state.observed.navigationModels.first)

        #expect(await router.state.observed.selectedModelId == selectedModel.id)

        await router.dispatch(.dismiss(.model(selectedModel)))

        #expect(await router.state.observed.rootSelectedModelID == rootSelectedModel.id)
        #expect(await router.state.observed.selectedModelId == rootSelectedModel.id)
    }

    @Test("Dismiss all presented models") func testDismissAllPResentedModels() async throws {
        let router = await generateRouter()

        await router.dispatch(.open(path: .create("/third"), in: .new()))
        await router.dispatch(.open(path: .create("/third"), in: .new()))
        await router.dispatch(.open(path: .create("/third"), in: .new()))

        #expect(await router.state.observed.navigationModels.filter { $0.isPresented }.count == 3)

        await router.dispatch(.dismiss(.allPresented()))

        #expect(await router.state.observed.navigationModels.filter { $0.isPresented }.count == 0)
    }

    @Test("Dismiss pop to root") func testDismissPopToRoot() async throws {
        let router = await generateRouter()

        let model = try await #require(router.state.observed.navigationModels.last)

        await router.dispatch(.open(path: SwiftRouter.Path.create("/third"), in: .model(model)))
        await router.dispatch(.open(path: SwiftRouter.Path.create("/third"), in: .model(model)))
        await router.dispatch(.open(path: SwiftRouter.Path.create("/third"), in: .model(model)))

        #expect(await router.state.observed.navigationModels.last?.presentedPaths.first?.path == "/second")
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.last?.path == "/third")
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.count == 4)

        await router.dispatch(.dismiss(.popToRoot(byModelId: model.id)))

        #expect(await router.state.observed.navigationModels.last?.presentedPaths.count == 1)
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.first?.path == "/second")
    }

    @Test("Update action") func testUpdateAction() async throws {
        let router = await generateRouter(availableRoutes: [
            .init("/<string:value>", rules: ["value": .oneOf([.string("first"), .string("fourth")])]),
            .init("/second"),
            .init("/third"),
        ])

        let desiredPath = try await #require(router.state.observed.navigationModels.first?.selectedPath)
        let selectedModel = try await #require(router.state.observed.navigationModels.first)

        // Add some extra paths
        await router.dispatch(.open(path: .create("/second"), in: .model(selectedModel)))
        await router.dispatch(.open(path: .create("/second"), in: .model(selectedModel)))
        #expect(await router.state.observed.navigationModels.first?.presentedPaths.count == 3)

        await router.dispatch(.update(path: desiredPath, withURL: URL(string: "/fourth"), in: selectedModel, withHapticFeedback: false))

        #expect(await router.state.observed.navigationModels.first?.selectedPath.id == desiredPath.id)
        #expect(await router.state.observed.navigationModels.first?.selectedPath.path == "/fourth")
        #expect(await router.state.observed.navigationModels.first?.presentedPaths.count == 1)
    }

    @Test("Set selected path") func testSetSelectedPath() async throws {
        let router = await generateRouter()

        let desiredPath = try #require(SwiftRouter.Path.create("/first"))
        let desiredModel = try await #require(router.state.observed.navigationModels.last)

        await router.dispatch(.open(path: desiredPath, in: .model(desiredModel)))
        await router.dispatch(.open(path: .create("/second"), in: .model(desiredModel)))
        await router.dispatch(.open(path: .create("/second"), in: .model(desiredModel)))

        await router.dispatch(.setSelectedPath(to: desiredPath, in: desiredModel))

        #expect(await router.state.observed.navigationModels.last?.selectedPath.id == desiredPath.id)
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.count == 2)
        #expect(await router.state.observed.navigationModels.last?.presentedPaths.last?.id == desiredPath.id)
    }

    @Test("Test multi action") func testMultiAction() async throws {
        let router = await generateRouter()

        let desiredSelectedPath = try #require(SwiftRouter.Path.create("/third"))

        await router.dispatch(SwiftRouter.Action {
            SwiftRouter.Action.open(
                path: .create("/first")
            )
            SwiftRouter.Action.multiAction([
                SwiftRouter.Action.open(
                    path: .create("/second")
                ),
                SwiftRouter.Action.open(
                    path: desiredSelectedPath
                ),
            ])
        })
        #expect(await router.state.observed.navigationModels.first?.presentedPaths.count == 4)
        #expect(await router.state.observed.navigationModels.first?.selectedPath.id == desiredSelectedPath.id)
    }

    @Test("Test that non-duplicated-allowed routes cannot be added more than once") func testNonDuplicatedAllowedRoutesCannotBeAddedOnce() async throws {
        let selectedPath = try #require(SwiftRouter.Path.create("/first"))
        let router = await generateRouter(
            firstModel: .create(
                selectedPath: selectedPath,
                tab: .init(name: "Tab1", icon: .iconImage(id: "tab1Icon")),
            ),
            availableRoutes: [
                .init("/first", allowsDuplicates: false),
                .init("/second"),
                .init("/third"),
                .init(
                    "/hello/<string:name>",
                    rules: [
                        "name": .oneOf([
                            .string("awesome"),
                            .string("cool"),
                        ]),
                    ],
                    allowsDuplicates: false
                ),
            ]
        )

        let newPath = try #require(SwiftRouter.Path.create("/third"))

        await router.dispatch(SwiftRouter.Action {
            SwiftRouter.Action.open(
                path: newPath
            )
            SwiftRouter.Action.open(
                path: SwiftRouter.Path.create("/first")
            )
        })

        #expect(await router.state.observed.navigationModels.first?.selectedPath == selectedPath)

        let oneOfPath = try #require(SwiftRouter.Path.create("/hello/awesome"))
        await router.dispatch(.open(
            path: oneOfPath
        ))

        let thepath = await router.state.observed.navigationModels.first?.selectedPath

        #expect(thepath?.id == oneOfPath.id)
        #expect(thepath?.path == oneOfPath.path)

        let oneOfPath2 = try #require(SwiftRouter.Path.create("/hello/cool"))
        await router.dispatch(.open(
            path: oneOfPath2
        ))

        #expect(await router.state.observed.navigationModels.first?.selectedPath.id == oneOfPath.id)
        #expect(try await router.state.observed.navigationModels.first?.selectedPath.path == oneOfPath2.path)
    }

    @MainActor func generateRouter(
        firstModel: SwiftRouter.Model = .create(
            selectedPath: SwiftRouter.Path.create("/first")!,
            tab: .init(name: "Tab1", icon: .iconImage(id: "tab1Icon")),
        ),
        secondModel: SwiftRouter.Model = .create(
            selectedPath: SwiftRouter.Path.create("/second")!,
            tab: .init(name: "Tab2", icon: .iconImage(id: "tab2Icon"))
        ),
        availableRoutes: [SwiftRouter.Route] = [
            .init("/first"),
            .init("/second"),
            .init("/third"),
        ]

    ) -> SwiftRouter.Router {
        let initState: SwiftRouter.State = .init(
            observed: .init(
                navigationModels: [firstModel, secondModel],
                availableRoutes: availableRoutes
            )
        )
        return SwiftRouter.RouterImpl(initState: initState)
    }
}
