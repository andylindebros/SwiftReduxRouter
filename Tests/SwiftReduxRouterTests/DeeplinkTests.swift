@testable import SwiftReduxRouter
import XCTest

final class DeeplinkTests: XCTestCase {
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

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/3")))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.add(path: path, to: navigationTarget) = pushAction,
            case let NavigationTarget.navigationModel(foundModel, animate: true) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }

        XCTAssertEqual(foundModel.id, navigationModel2.id)
        XCTAssertEqual(path.path, "/route/3")
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

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/new/route/3")))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        guard
            case let NavigationAction.add(path: path, to: navigationTarget) = pushAction,
            case let NavigationTarget.new(navigationModelPath, type: type) = navigationTarget
        else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }
        XCTAssertNil(navigationModelPath)
        XCTAssertEqual(type, .regular)
        XCTAssertEqual(path.path, "/new/route/3")
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

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel2/route/2")))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)
        
        guard
            case let NavigationAction.setSelectedPath(to: path, in: navigationModel) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        XCTAssertEqual(navigationModel.id, navigationModel2.id)
        XCTAssertEqual(try XCTUnwrap(path.path), "/route/2")
    }

    func testNoFurtherURL() throws {
        let navigationModel1 = NavigationModel.createInitModel(
            path: NavigationPath(URL(string: "/navigationModel1")),
            selectedPath: NavigationPath(URL(string: "/route"))
        )

        let state = NavigationState(navigationModels: [navigationModel1])

        var deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigationModel1")))

        let reaction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.setSelectedPath(to: path, in: _) = reaction
        else {
            return XCTFail("NavigationAction \(reaction) was not expected")
        }
        
        XCTAssertEqual(path.path, "/route")

        // Test can handle no url
        deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com")))
        XCTAssertNil(deeplinkAction.action(for: state))
    }

    func testCanCreateNavigationBasedOnNavigationModelRoute() throws {
        let state = NavigationState(navigationModels: [], availableNavigationModelRoutes: [NavigationRoute("/navigation1"), NavigationRoute("/navigation2")])

        let deeplinkAction = try XCTUnwrap(NavigationAction.Deeplink(with: URL(string: "swiftreduxrouter://www.example.com/navigation2/awesome")))

        let pushAction = try XCTUnwrap(deeplinkAction.action(for: state) as? NavigationAction)

        guard
            case let NavigationAction.add(path: path, to: navigationTarget) = pushAction,
            case let NavigationTarget.new(navigationModelPath, type: type) = navigationTarget else {
            return XCTFail("NavigationAction \(pushAction) was not expected")
        }
        XCTAssertEqual(try XCTUnwrap(navigationModelPath).path, "/navigation2")
        XCTAssertEqual(type, .regular)
        XCTAssertEqual(path.path, "/awesome")
    }
}
