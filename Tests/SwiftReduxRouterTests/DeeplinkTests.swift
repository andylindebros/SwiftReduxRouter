@testable import SwiftReduxRouter
import XCTest

final class DeeplinkTests: XCTestCase {
    func testDeeplinkActions() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1")],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2")],
            selectedPath: NavPath(URL(string: "/awesome"))
        )

        let navigationModel3 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel3/awesome")],
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
                    .init("/awesome"),
                    .init("/route/<int:whatever>"),
                ]
            )
        )

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3")))

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
            routes: [NavigationRoute("/<string:awesome>")],
            selectedPath: path
        )
        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1],
                availableRoutes: [
                    .init("/<string:awesome>", rules: ["awesome": .any]),
                ]
            )
        )

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/najs")))
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
            routes: [NavigationRoute("/navigationModel1")],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2")],
            selectedPath: NavPath(URL(string: "/route/2"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [.init("/new/route/<int:whatever>")]
            )
        )

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/new/route/3")))

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
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1")],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let selectedPath = NavPath(URL(string: "/route/2"))
        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2")],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [.init("/route/<int:awesome>")]
        ))

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3")))

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
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel1")],
            selectedPath: NavPath(URL(string: "/route/1"))
        )

        let selectedPath = NavPath(URL(string: "/route/2"))
        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/navigationModel2")],
            selectedPath: selectedPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1, navigationModel2],
            availableRoutes: [.init("/route/<int:awesome>")]
        ))

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/2")))

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
            routes: [NavigationRoute("/navigationModel1")],
            selectedPath: testPath
        )

        let state = Navigation.State(observed: .init(
            navigationModels: [navigationModel1],
            availableRoutes: [.init("/route")]
        ))

        var deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel1")))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.setSelectedPath(to: path, in: _) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }

        XCTAssertEqual(path.path, testPath.path)

        // Test can handle no url
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com")))
        XCTAssertNil(deeplinkAction.action(for: state))
    }

    func testCanHandleSimilarNavigationModelRoutes() async throws {
        let navigationModel1 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/<string:param>", rules: ["param": .oneOf([.string("foo"), .string("bar")])])],
            selectedPath: NavPath(URL(string: "/test"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            routes: [NavigationRoute("/test")],
            selectedPath: NavPath(URL(string: "/foo"))
        )

        let state = Navigation.State(
            observed: .init(
                navigationModels: [navigationModel1, navigationModel2],
                availableRoutes: [NavigationRoute("/<string:param>", rules: ["param": .oneOf([.string("foo"), .string("bar")])]), NavigationRoute("/test"), NavigationRoute("/present")]
            )
        )

        var deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/present")))

        var action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = action,
            case NavigationTarget.new = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/present")

        // Opens in first navigationModel since foo matches the navigationModel and /test allows multiple instances.
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/foo")))

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
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/test/present")))

        action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.open(path: path, in: navigationTarget) = action,
            case let NavigationTarget.navigationModel(model, _) = navigationTarget
        else {
            return XCTFail("NavigationAction \(action) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(path?.url?.path), "/present")
        XCTAssertEqual(navigationModel2.id, model.id)

        // Updates the second navigationModels selected path
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/test/bar")))

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
        XCTAssertEqual(try XCTUnwrap(updatePath.url?.path), "/foo")
        XCTAssertEqual(selectedPath.id, updatePath.id)
        XCTAssertEqual(try XCTUnwrap(url?.path), "/bar")
        XCTAssertEqual(navigationModel2.id, model.id)
        XCTAssertEqual(navigationModel2.id, selectedNavigationModel.id)
    }
}
