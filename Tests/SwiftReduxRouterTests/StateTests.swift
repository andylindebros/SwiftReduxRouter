@testable import SwiftReduxRouter
import XCTest

final class StateTests: XCTestCase {
    func testDeeplinkActions() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel1")),
            selectedPath: NavigationPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel2")),
            selectedPath: NavigationPath(URL(string: "/route/2"))
        )

        let navigationModel3 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel2/awesome")),
            selectedPath: NavigationPath(URL(string: "/route/2"))
        )

        let state = NavigationState(navigationModels: [navigationModel1, navigationModel2, navigationModel3])

        let deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3")))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationActions.Push)

        guard case let NavigationTarget.navigationModel(foundModel, animate: true) = pushAction.target else {
            return XCTFail("NavigationTarget \(pushAction.target) was not expected")
        }

        XCTAssertEqual(foundModel.id, navigationModel2.id)
        XCTAssertEqual(pushAction.path.path, "/route/3")
    }

    func testPresentNewNavigationModel() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel1")),
            selectedPath: NavigationPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel2")),
            selectedPath: NavigationPath(URL(string: "/route/2"))
        )

        let state = NavigationState(navigationModels: [navigationModel1, navigationModel2])

        let deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/new/route/3")))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationActions.Push)

        guard case let NavigationTarget.new(navigationModelPath, type: type) = pushAction.target else {
            return XCTFail("NavigationTarget \(pushAction.target) was not expected")
        }
        XCTAssertNil(navigationModelPath)
        XCTAssertEqual(type, .regular)
        XCTAssertEqual(pushAction.path.path, "/new/route/3")
    }

    func testAlreadyPresentedPath() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel1")),
            selectedPath: NavigationPath(URL(string: "/route/1"))
        )

        let navigationModel2 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel2")),
            selectedPath: NavigationPath(URL(string: "/route/2"))
        )

        let state = NavigationState(navigationModels: [navigationModel1, navigationModel2])

        let deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/2")))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationActions.SetSelectedPath)
        XCTAssertEqual(reaction.navigationModel.id, navigationModel2.id)
        XCTAssertEqual(try XCTUnwrap(reaction.navigationPath.path), "/route/2")
    }

    func testNoFurtherURL() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel1")),
            selectedPath: NavigationPath(URL(string: "/route"))
        )

        let state = NavigationState(navigationModels: [navigationModel1])

        var deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel1")))

        let action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationActions.SetSelectedPath)

        XCTAssertEqual(action.navigationPath.path, "/route")

        // Test can handle no url
        deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com")))
        XCTAssertNil(deeplinkAction.action(for: state))
    }

    func testCanCreateNavigationBasedOnNavigationModelRoute() throws {
        let state = NavigationState(navigationModels: [], navigationModelRoutes: [NavigationRoute("/navigation1"), NavigationRoute("/navigation2")])

        let deeplinkAction = try XCTUnwrap(NavigationActions.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigation2/awesome")))

        let action = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationActions.Push)

        guard case let NavigationTarget.new(navigationModelPath, type: type) = action.target else {
            return XCTFail("NavigationTarget \(action.target) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(navigationModelPath).path, "/navigation2")
        XCTAssertEqual(type, .regular)
        XCTAssertEqual(action.path.path, "/awesome")
    }
}
