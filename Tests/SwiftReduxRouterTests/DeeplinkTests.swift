@testable import SwiftReduxRouter
import XCTest

final class DeeplinkTests: XCTestCase {
    func testDeeplinkActions() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1", accessLevel: .public)],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let navigaionModel2CategoryRoute = NavigationRoute("/navigationModel2", accessLevel: .public)
        let navigationModel2 = NavigationModel.createInitModel(
            routes: [
                navigaionModel2CategoryRoute,
                navigaionModel2CategoryRoute.append(.init("/route/<int:whatever>", accessLevel: .public))
            ],
            selectedPath: NavPath(URL(string: "/awesome"))
        )

        let navigationModel3 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel3/awesome", accessLevel: .public)],
            selectedPath: NavPath(URL(string: "/route/2"))
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

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = pushAction,
            case let NavigationTarget.navigationModel(foundModel, animate: true) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }

        XCTAssertEqual(foundModel.id, navigationModel2.id)
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/route/3")
    }

    func testDontRemoveIfNoPathIsLeft() throws {
        let path = NavPath(URL(string: "/cool"))
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/<string:awesome>", accessLevel: .public)],
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

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/najs"), accessLevel: .public))
        let action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.multiAction(actions) = action,
            let updateAction = actions.first,
            case let NavigationAction.update(path: updatePath, withURL: url, in: model) = updateAction,
            let selectAction = actions.last,
            case let NavigationAction.setSelectedPath(to: selectedPath, in: selectedNavigationModel) = selectAction
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
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1", accessLevel: .public)],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2", accessLevel: .public)],
            selectedPath: NavPath(URL(string: "/route/2"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [.init("/new/route/<int:whatever>", accessLevel: .public)]
            )
        )

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/new/route/3"), accessLevel: .public))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = pushAction,
            case let NavigationTarget.new(navigationRoutes, type: type, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }
        XCTAssertNil(navigationRoutes)
        XCTAssertEqual(type, .regular())
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/new/route/3")
    }

    func testInstancePath() throws {
        let availableRoute = NavigationRoute("/route/<int:awesome>", accessLevel: .private)
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [
                NavigationRoute("/navigationModel1", accessLevel: .public).append(availableRoute),
            ],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let selectedPath = NavPath(URL(string: "/hello"))
        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2", accessLevel: .public).append(availableRoute)],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [availableRoute]
        ))

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = reaction,
            case let NavigationTarget.navigationModel(navigationModel, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.path), "/route/3")
        XCTAssertEqual(navigationModel.id, navigationModel2.id)
    }

    func testAlreadyPresentedPath() throws {
        let availabeleRoute = NavigationRoute("/route/<int:awesome>", accessLevel: .private)

        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1", accessLevel: .public).append(availabeleRoute)],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let selectedPath = NavPath(URL(string: "/route/2"))
        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2", accessLevel: .public).append(availabeleRoute)],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [availabeleRoute]
        ))

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/2"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.setSelectedPath(to: path, in: navigationModel) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        XCTAssertEqual(navigationModel.id, navigationModel2.id)
        XCTAssertEqual(selectedPath.id, path.id)
        XCTAssertEqual(try XCTUnwrap(path.path), "/route/2")
    }

    func testSelectTab() throws {
        let testPath = NavPath(URL(string: "/route"))
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1", accessLevel: .public)],
            selectedPath: testPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1],
            availableRoutes: [.init("/route", accessLevel: .public)]
        ))

        var deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel1"), accessLevel: .public))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.setSelectedPath(to: path, in: _) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }

        XCTAssertEqual(path.path, testPath.path)

        // Test can handle no url
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com"), accessLevel: .public))
        XCTAssertNil(deeplinkAction.action(for: state))
    }

    func testCanHandleSimilarNavigationModelRoutes() async throws {
        let availableRoute1 = NavigationRoute("/<string:param>", rules: ["param": .oneOf([.string("foo"), .string("bar")])], accessLevel: .private)
        let availableRoute2 = NavigationRoute("/test", accessLevel: .private)
        let availableRoute3 = NavigationRoute("/present", accessLevel: .public)
        let availableRoute4 = NavigationRoute("/awesome/<string:param>", rules: ["param": .oneOf([.string("awesome"), .string("Hello")])], accessLevel: .private)

        let navigationModel1 = NavigationModel.createInitModel(
            routes: [
                NavigationRoute("", accessLevel: .public).append(availableRoute1),
                NavigationRoute("", accessLevel: .public).append(availableRoute2).append(availableRoute4),
            ],
            selectedPath: NavPath(URL(string: "/awesome/hello"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/test", accessLevel: .public)],
            selectedPath: NavPath(URL(string: "/foo"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [availableRoute1, availableRoute2, availableRoute3, availableRoute4]
            )
        )

        var deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/present"), accessLevel: .public))

        var action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = action,
            case NavigationTarget.new = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/present")

        // Opens in first navigationModel since foo matches the navigationModel and /test allows multiple instances.
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/foo"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = action,
            case let NavigationTarget.navigationModel(model, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/foo")
        XCTAssertEqual(navigationModel1.id, model.id)

        // Opens in second navigationModel
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/test"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = action,
            case let NavigationTarget.navigationModel(model, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/test")
        XCTAssertEqual(navigationModel2.id, model.id)

        // Updates the first navigationModels selected path
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/test/awesome/awesome"), accessLevel: .public))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.multiAction(actions) = action,
            let updateAction = actions.first,
            case let NavigationAction.update(path: updatePath, withURL: url, in: model) = updateAction,
            let selectAction = actions.last,
            case let NavigationAction.setSelectedPath(to: selectedPath, in: selectedNavigationModel) = selectAction
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
