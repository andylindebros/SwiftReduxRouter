@testable import SwiftReduxRouting
import SwiftUI
import XCTest

final class RouterTests: XCTestCase {
    func testSetupViews() {
        let sessions = [
            RouterModels.Session(
                name: "tab1",
                path: RouterModels.Path(path: "/one/awesome"),
                tab: RouterModels.Tab(
                    name: "First",
                    icon: "tab_search",
                    selectedIcon: "tab_search_selected"
                )
            ),
            RouterModels.Session(
                name: "tab2",
                path: RouterModels.Path(path: "/two"),
                tab: RouterModels.Tab(
                    name: "Second",
                    icon: "tab_favorite",
                    selectedIcon: "tab_favorite_selected"
                )
            ),
        ]

        let state = RouterState(sessions: sessions)

        _ = Router(
            routerState: state,
            routes: [
                Router.Route(
                    path: "/one/<string:item>",
                    onWillAppear: { path, params in
                        XCTAssertEqual(path.path, "/one/awesome")
                        let item = params["item"] as! String
                        XCTAssertEqual(item, "awesome")
                    },
                    render: { path, params -> AnyView in
                        XCTAssertEqual(path.path, "/one/awesome")
                        let item = params["item"] as! String
                        XCTAssertEqual(item, "awesome")
                        return AnyView(Text("first route"))
                    }
                ),
                Router.Route(
                    path: "/two",
                    onWillAppear: { path, params in
                        XCTAssertEqual(path.path, "/two")
                    },
                    render: { path, params -> AnyView in
                        XCTAssertEqual(path.path, "/two")
                        return AnyView(Text("Second route"))
                    }
                ),
            ]
        ) { session in

        } onDismiss: { session in
        }
    }
}
