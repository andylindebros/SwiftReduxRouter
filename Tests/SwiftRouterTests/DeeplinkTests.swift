@testable import SwiftRouter
import XCTest

// swiftlint:disable function_body_length
final class DeeplinkTests: XCTestCase {
    func testDeeplinkActions() throws {
        let navigationModel1 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel1", accessLevel: .public)],
            selectedPath: Navigation.Path(URL(string: "/route/1"))
        )

        let navigaionModel2CategoryRoute = Navigation.Route("/navigationModel2", accessLevel: .public)
        let navigationModel2 = Navigation.Model.create(
            routes: [
                navigaionModel2CategoryRoute,
                navigaionModel2CategoryRoute.append(.init("/route/<int:whatever>", accessLevel: .public)),
            ],
            selectedPath: Navigation.Path(URL(string: "/awesome"))
        )

        let navigationModel3 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel3/awesome", accessLevel: .public)],
            selectedPath: Navigation.Path(URL(string: "/route/2"))
        )

        let state = Navigation.State(
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

        let deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)

        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = pushAction,
            case let Navigation.Target.model(foundModel, animate: true) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }

        XCTAssertEqual(foundModel.id, navigationModel2.id)
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/route/3")
    }

    func testDontRemoveIfNoPathIsLeft() throws {
        let path = Navigation.Path(URL(string: "/cool"))
        let navigationModel1 = Navigation.Model.create(
            routes: [Navigation.Route("/<string:awesome>", accessLevel: .public)],
            selectedPath: path
        )
        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1],
                availableRoutes: [
                    .init("/<string:awesome>", rules: ["awesome": .any], accessLevel: .public),
                ]
            )
        )

        let deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/najs"), accessLevel: .public))
        let action = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)

        guard
            case let Navigation.Action.multiAction(actions) = action,
            let updateAction = actions.first,
            case let Navigation.Action.update(path: updatePath, withURL: url, in: model) = updateAction,
            let selectAction = actions.last,
            case let Navigation.Action.setSelectedPath(to: selectedPath, in: selectedNavigationModel) = selectAction
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }

        XCTAssertEqual(updatePath.id, path.id)
        XCTAssertEqual(model.id, navigationModel1.id)
        XCTAssertEqual(try XCTUnwrap(url?.path), "/najs")

        XCTAssertEqual(selectedPath.id, path.id)
        XCTAssertEqual(selectedNavigationModel.id, navigationModel1.id)
    }

    func testPresentNewNavigationModel() throws {
        let navigationModel1 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel1", accessLevel: .public)],
            selectedPath: Navigation.Path(URL(string: "/route/1"))
        )

        let navigationModel2 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel2", accessLevel: .public)],
            selectedPath: Navigation.Path(URL(string: "/route/2"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [.init("/new/route/<int:whatever>", accessLevel: .public)]
            )
        )

        let deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/new/route/3"), accessLevel: .public))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)
        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = pushAction,
            case let Navigation.Target.new(navigationRoutes, type: type) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }
        XCTAssertNil(navigationRoutes)
        XCTAssertEqual(type, Navigation.PresentationType.pageSheet())
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/new/route/3")
    }

    func testInstancePath() throws {
        let availableRoute = Navigation.Route("/route/<int:awesome>", accessLevel: .private)
        let navigationModel1 = Navigation.Model.create(
            routes: [
                Navigation.Route("/navigationModel1", accessLevel: .public).append(availableRoute),
            ],
            selectedPath: Navigation.Path(URL(string: "/route/1"))
        )

        let selectedPath = Navigation.Path(URL(string: "/hello"))
        let navigationModel2 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel2", accessLevel: .public).append(availableRoute)],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [availableRoute]
        ))

        let deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)

        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = reaction,
            case let Navigation.Target.model(navigationModel, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.path), "/route/3")
        XCTAssertEqual(navigationModel.id, navigationModel2.id)
    }

    func testAlreadyPresentedPath() throws {
        let availabeleRoute = Navigation.Route("/route/<int:awesome>", accessLevel: .private)

        let navigationModel1 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel1", accessLevel: .public).append(availabeleRoute)],
            selectedPath: Navigation.Path(URL(string: "/route/1"))
        )

        let selectedPath = Navigation.Path(URL(string: "/route/2"))
        let navigationModel2 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel2", accessLevel: .public).append(availabeleRoute)],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [availabeleRoute]
        ))

        let deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel2/route/2"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)

        guard
            case let Navigation.Action.setSelectedPath(to: path, in: navigationModel) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        XCTAssertEqual(navigationModel.id, navigationModel2.id)
        XCTAssertEqual(selectedPath.id, path.id)
        XCTAssertEqual(try XCTUnwrap(path.path), "/route/2")
    }

    func testSelectTab() throws {
        let testPath = Navigation.Path(URL(string: "/route"))
        let navigationModel1 = Navigation.Model.create(
            routes: [Navigation.Route("/navigationModel1", accessLevel: .public)],
            selectedPath: testPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1],
            availableRoutes: [.init("/route", accessLevel: .public)]
        ))

        var deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/navigationModel1"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)

        guard
            case let Navigation.Action.setSelectedPath(to: path, in: _) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }

        XCTAssertEqual(path.path, testPath.path)

        // Test can handle no url
        deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com"), accessLevel: .public))
        XCTAssertNil(deeplinkAction.action(for: state))
    }

    func testCanHandleSimilarNavigationModelRoutes() async throws {
        let availableRoute1 = Navigation.Route("/<string:param>", rules: ["param": .oneOf([.string("foo"), .string("bar")])], accessLevel: .private)
        let availableRoute2 = Navigation.Route("/test", accessLevel: .private)
        let availableRoute3 = Navigation.Route("/present", accessLevel: .public)
        let availableRoute4 = Navigation.Route("/awesome/<string:param>", rules: ["param": .oneOf([.string("awesome"), .string("Hello")])], accessLevel: .private)

        let navigationModel1 = Navigation.Model.create(
            routes: [
                Navigation.Route("", accessLevel: .public).append(availableRoute1),
                Navigation.Route("", accessLevel: .public).append(availableRoute2).append(availableRoute4),
            ],
            selectedPath: Navigation.Path(URL(string: "/awesome/hello"))
        )

        let navigationModel2 = Navigation.Model.create(
            routes: [Navigation.Route("/test", accessLevel: .public)],
            selectedPath: Navigation.Path(URL(string: "/foo"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [availableRoute1, availableRoute2, availableRoute3, availableRoute4]
            )
        )

        var deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/present"), accessLevel: .public))

        var action = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)
        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = action,
            case Navigation.Target.new = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/present")

        // Opens in first navigationModel since foo matches the navigationModel and /test allows multiple instances.
        deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/foo"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)
        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = action,
            case let Navigation.Target.model(model, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/foo")
        XCTAssertEqual(navigationModel1.id, model.id)

        // Opens in second navigationModel
        deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/test"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)
        guard
            case let Navigation.Action.open(path: path, in: navigationTarget) = action,
            case let Navigation.Target.model(model, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/test")
        XCTAssertEqual(navigationModel2.id, model.id)

        // Updates the first navigationModels selected path
        deeplinkAction = try XCTUnwrap(Navigation.Action.Deeplink(with: URL(string: "app://www.example.com/test/awesome/awesome"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? Navigation.Action)
        guard
            case let Navigation.Action.multiAction(actions) = action,
            let updateAction = actions.first,
            case let Navigation.Action.update(path: updatePath, withURL: url, in: model) = updateAction,
            let selectAction = actions.last,
            case let Navigation.Action.setSelectedPath(to: selectedPath, in: selectedNavigationModel) = selectAction
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(updatePath.url?.path), "/awesome/hello")
        XCTAssertEqual(selectedPath.id, updatePath.id)
        XCTAssertEqual(try XCTUnwrap(url?.path), "/awesome/awesome")
        XCTAssertEqual(navigationModel1.id, model.id)
        XCTAssertEqual(navigationModel1.id, selectedNavigationModel.id)
    }
}
// swiftlint:enable function_body_length
