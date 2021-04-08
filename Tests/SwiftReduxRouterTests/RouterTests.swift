@testable import SwiftReduxRouter
import SwiftUI
import XCTest

final class RouterTests: XCTestCase {
    func testSetupViews() {
        let sessions = [
            NavigationSession(
                name: "tab1",
                path: NavigationPath("/one/awesome"),
                tab: NavigationTab(
                    name: "First",
                    icon: "tab_search",
                    selectedIcon: "tab_search_selected"
                )
            ),
            NavigationSession(
                name: "tab2",
                path: NavigationPath("/two"),
                tab: NavigationTab(
                    name: "Second",
                    icon: "tab_favorite",
                    selectedIcon: "tab_favorite_selected"
                )
            ),
        ]

        let state = NavigationState(sessions: sessions)

        _ = RouterView(
            navigationState: state,
            routes: [
                RouterView.Route(
                    path: "/one/<string:item>",
                    onWillAppear: { path, params in
                        XCTAssertEqual(path.path, "/one/awesome")
                        let item = params["item"] as! String
                        XCTAssertEqual(item, "awesome")
                    },
                    render: { session, params, _ -> AnyView in
                        XCTAssertEqual(session.nextPath.path, "/one/awesome")
                        let item = params["item"] as! String
                        XCTAssertEqual(item, "awesome")
                        return AnyView(Text("first route"))
                    }
                ),
                RouterView.Route(
                    path: "/two",
                    onWillAppear: { path, params in
                        XCTAssertEqual(path.path, "/two")
                    },
                    render: { session, params, _ -> AnyView in
                        XCTAssertEqual(session.nextPath.path, "/two")
                        return AnyView(Text("Second route"))
                    }
                ),
            ]
        ) { session in

        } onDismiss: { session in
        }
    }
}
