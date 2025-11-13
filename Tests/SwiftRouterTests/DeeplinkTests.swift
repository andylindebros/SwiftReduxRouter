import Foundation
@testable import SwiftRouter
import Testing

// swiftlint:disable function_body_length
@Suite(.serialized)
struct DeeplinkTests {
    @Test("Test load by slug alias")
    func testDeeplinkActions() async throws {
        let navigationModel1 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/navigationModel1", accessLevel: .public)],
            selectedPath: SwiftRouter.Path(URL(string: "/route/1"))
        )

        let navigaionModel2CategoryRoute = SwiftRouter.Route("/navigationModel2", accessLevel: .public)
        let navigationModel2 = SwiftRouter.Model.create(
            routes: [
                navigaionModel2CategoryRoute,
                navigaionModel2CategoryRoute.append(.init("/route/<int:whatever>", accessLevel: .public)),
            ],
            selectedPath: SwiftRouter.Path(URL(string: "/awesome"))
        )

        let navigationModel3 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/navigationModel3/awesome", accessLevel: .public)],
            selectedPath: SwiftRouter.Path(URL(string: "/route/2"))
        )

        let state = SwiftRouter.State(
            observed: .init(
                navigationModels: [
                    navigationModel1,
                    navigationModel2,
                    navigationModel3,
                ],
                availableRoutes: [
                    .init("/awesome", accessLevel: .public),
                    .init("/route/<int:whatever>", accessLevel: .public),
                ]
            )
        )

        let deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let pushAction = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)

        guard
            case let SwiftRouter.Action.multiAction(actions) = pushAction,
            let openAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = openAction,
            case let SwiftRouter.Model.Target.model(foundModel, animate: true) = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(pushAction) was not expected")
        }

        #expect(foundModel.id == navigationModel2.id)
        #expect(path?.url?.path == "/route/3")
    }

    @Test("Don't remove if no path is left")
    func testDontRemoveIfNoPathIsLeft() throws {
        let path = SwiftRouter.Path(URL(string: "/cool"))
        let navigationModel1 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/<string:awesome>", rules: ["awesome": .any], accessLevel: .public, allowsDuplicates: false)],
            selectedPath: path
        )
        let state = SwiftRouter.State(
            observed: .init(
                navigationModels: [navigationModel1],
                availableRoutes: [
                    .init("/<string:awesome>", rules: ["awesome": .any], accessLevel: .public, allowsDuplicates: false),
                ]
            )
        )

        let deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/najs"), accessLevel: .public))
        let action = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)

        guard
            case let SwiftRouter.Action.update(path: updatePath, withURL: url, in: model, _) = action
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(action) was not expected")
        }

        #expect(updatePath.id == path.id)
        #expect(model.id == navigationModel1.id)
        #expect(url?.path == "/najs")
    }

    @Test("Present new navigation model")
    func testPresentNewNavigationModel() throws {
        let navigationModel1 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/navigationModel1", accessLevel: .public)],
            selectedPath: SwiftRouter.Path(URL(string: "/route/1"))
        )

        let navigationModel2 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/navigationModel2", accessLevel: .public)],
            selectedPath: SwiftRouter.Path(URL(string: "/route/2"))
        )

        let state = SwiftRouter.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [.init("/new/route/<int:whatever>", accessLevel: .public)]
            )
        )

        let deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/new/route/3"), accessLevel: .public))

        let multiAction = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)
        guard
            case let SwiftRouter.Action.multiAction(actions) = multiAction,
            let pushAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = pushAction,
            case let SwiftRouter.Model.Target.new(navigationRoutes, type: type) = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(multiAction) was not expected")
        }
        #expect(navigationRoutes == nil)
        #expect(type == SwiftRouter.Model.PresentationType.pageSheet())
        #expect(path?.url?.path == "/new/route/3")
    }

    @Test("Test instance path")
    func testInstancePath() throws {
        let availableRoute = SwiftRouter.Route("/route/<int:awesome>", accessLevel: .private)
        let navigationModel1 = SwiftRouter.Model.create(
            routes: [
                SwiftRouter.Route("/navigationModel1", accessLevel: .public).append(availableRoute),
            ],
            selectedPath: SwiftRouter.Path(URL(string: "/route/1"))
        )

        let selectedPath = SwiftRouter.Path(URL(string: "/hello"))
        let navigationModel2 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/navigationModel2", accessLevel: .public).append(availableRoute)],
            selectedPath: selectedPath
        )

        let state = SwiftRouter.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [availableRoute]
        ))

        let deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let reaction = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)

        guard
            case let SwiftRouter.Action.multiAction(actions) = reaction,
            let pushAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = pushAction,
            case let SwiftRouter.Model.Target.model(navigationModel, _) = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(reaction) was not expected")
        }
        #expect(path?.path == "/route/3")
        #expect(navigationModel.id == navigationModel2.id)
    }

    @Test("Can handle similar navigation model routes")
    func testCanHandleSimilarNavigationModelRoutes() async throws {
        let availableRoute1 = SwiftRouter.Route("/<string:param>", rules: ["param": .oneOf([.string("foo"), .string("bar")])], accessLevel: .private)
        let availableRoute2 = SwiftRouter.Route("/test", accessLevel: .private)
        let availableRoute3 = SwiftRouter.Route("/present", accessLevel: .public)
        let availableRoute4 = SwiftRouter.Route("/awesome/<string:param>", rules: ["param": .oneOf([.string("awesome"), .string("Hello")])], accessLevel: .private, allowsDuplicates: false)

        let navigationModel1 = SwiftRouter.Model.create(
            routes: [
                SwiftRouter.Route("", accessLevel: .public).append(availableRoute1),
                SwiftRouter.Route("", accessLevel: .public).append(availableRoute2).append(availableRoute4),
            ],
            selectedPath: SwiftRouter.Path(URL(string: "/awesome/hello"))
        )

        let navigationModel2 = SwiftRouter.Model.create(
            routes: [SwiftRouter.Route("/test", accessLevel: .public)],
            selectedPath: SwiftRouter.Path(URL(string: "/foo"))
        )

        let state = SwiftRouter.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [availableRoute1, availableRoute2, availableRoute3, availableRoute4]
            )
        )

        var deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/present"), accessLevel: .public))

        var action = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)
        guard
            case let SwiftRouter.Action.multiAction(actions) = action,
            let pushAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = pushAction,
            case SwiftRouter.Model.Target.new = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(action) was not expected")
        }
        #expect(path?.url?.path == "/present")

        // Opens in first navigationModel since foo matches the navigationModel and /test allows multiple instances.
        deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/foo"), accessLevel: .public))

        action = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)
        guard
            case let SwiftRouter.Action.multiAction(actions) = action,
            let pushAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = pushAction,
            case let SwiftRouter.Model.Target.model(model, _) = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(action) was not expected")
        }
        #expect(path?.url?.path == "/foo")
        #expect(navigationModel1.id == model.id)

        // Opens in second navigationModel
        deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/test"), accessLevel: .public))

        action = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)
        guard
            case let SwiftRouter.Action.multiAction(actions) = action,
            let pushAction = actions.first,
            case let SwiftRouter.Action.open(path: path, in: navigationTarget, _) = pushAction,
            case let SwiftRouter.Model.Target.model(model, _) = navigationTarget
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(action) was not expected")
        }
        #expect(path?.url?.path == "/test")
        #expect(navigationModel2.id == model.id)

        // Updates the first navigationModels selected path
        deeplinkAction = try #require(SwiftRouter.Action.Deeplink(with: URL(string: "app://www.example.com/test/awesome/awesome"), accessLevel: .public))

        action = try #require(deeplinkAction.action(for: state) as? SwiftRouter.Action)
        guard
            case let SwiftRouter.Action.update(path: updatePath, withURL: url, in: model, _) = action
        else {
            throw NavigationTestError.unexpectedWithMessage("NavigationAction \(action) was not expected")
        }
        #expect(updatePath.url?.path == "/awesome/hello")
        #expect(url?.path == "/awesome/awesome")
        #expect(navigationModel1.id == model.id)
    }
}

// swiftlint:enable function_body_length

enum NavigationTestError: Error {
    case unexpectedWithMessage(String)
}
