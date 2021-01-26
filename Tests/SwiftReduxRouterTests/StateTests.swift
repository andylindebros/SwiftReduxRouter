@testable import SwiftReduxRouter
import XCTest

final class StateTests: XCTestCase {
    func testNewState() {
        let state = NavigationState()

        let newState = navigationReducer(
            action: NavigationActions.Push(
                path: NavigationPath("/whatever"),
                target: "whatever"
            ),
            state: state
        )

        XCTAssertEqual(newState.sessions.last!.name, "whatever")
        XCTAssertEqual(newState.sessions.last!.nextPath.path, "/whatever")
        XCTAssertEqual(newState.sessions.last!.selectedPath.path, "")
        XCTAssertEqual(state.selectedSessionId, newState.sessions.last!.id)
    }

    func testUpdateSelectedRoute() throws {
        let sessions = [
            NavigationSession(
                name: "tab1",
                path: NavigationPath("/one"),
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

        var state = NavigationState(sessions: sessions)

        let session = state.sessions[0]
        XCTAssertNotEqual(state.selectedSessionId, session.id)

        XCTAssertEqual(session.nextPath.path, "/one")
        XCTAssertEqual(session.presentedPaths.first!.path, "/one")

        state = navigationReducer(
            action: NavigationActions.Push(
                path: NavigationPath("/whatever"),
                target: "tab1"
            ),
            state: state
        )
        // second tab is now selected
        XCTAssertEqual(state.selectedSessionId, session.id)

        XCTAssertEqual(state.sessions.count, 2)
        XCTAssertEqual(state.sessions[0].nextPath.path, "/whatever")

        // Selected path should still not be updated. It should be updated by SetSelectedPath
        XCTAssertEqual(state.sessions[0].selectedPath.path, "/one")

        // The path should have been added to presented Paths
        XCTAssertEqual(state.sessions[0].presentedPaths.count, 2)
        XCTAssertEqual(state.sessions[0].presentedPaths.first!.path, "/one")
        XCTAssertEqual(state.sessions[0].presentedPaths.last!.path, "/whatever")

        state = navigationReducer(
            action: NavigationActions.SetSelectedPath(
                session: state.sessions[0]
            ),
            state: state
        )
        XCTAssertEqual(state.sessions[0].nextPath.path, "/whatever")
        XCTAssertEqual(state.sessions[0].selectedPath.path, "/whatever")

        // Push a new view to section session
        let secondTabSession = state.sessions[1]
        state = navigationReducer(
            action: NavigationActions.Push(
                path: NavigationPath("/nextViewTabTwo"),
                target: "tab2"
            ),
            state: state
        )
        XCTAssertEqual(state.selectedSessionId, secondTabSession.id)

        XCTAssertEqual(state.sessions.count, 2)
        XCTAssertEqual(state.sessions[1].nextPath.path, "/nextViewTabTwo")

        // Selected path should still not be updated. It should be updated by SetSelectedPath
        XCTAssertEqual(state.sessions[1].selectedPath.path, "/two")
        // The path should have been added to presented Paths
        XCTAssertEqual(state.sessions[1].presentedPaths.count, 2)
        XCTAssertEqual(state.sessions[1].presentedPaths.first!.path, "/two")
        XCTAssertEqual(state.sessions[1].presentedPaths.last!.path, "/nextViewTabTwo")

        // GoBack on the first tab whilte first session is in the background
        state = navigationReducer(
            action: NavigationActions.GoBack(
                target: "tab1",
                destination: .back
            ),
            state: state
        )

        XCTAssertEqual(state.sessions[0].nextPath.path, ":back")
        XCTAssertEqual(state.sessions[0].selectedPath.path, "/whatever")

        // This action simulates the action that are made from the router when the back action has been executed
        state = navigationReducer(
            action: NavigationActions.SetSelectedPath(
                session: session
            ),
            state: state
        )
        XCTAssertEqual(state.sessions[0].nextPath.path, "/one")
        XCTAssertEqual(state.sessions[0].selectedPath.path, "/one")

        // The path should have removed all presentedPaths that comes after the nextPath
        XCTAssertEqual(state.sessions[0].presentedPaths.count, 1)
        XCTAssertEqual(state.sessions[0].presentedPaths.first!.path, "/one")
    }

    func testPresentView() {
        let sessions = [
            NavigationSession(
                name: "tab1",
                path: NavigationPath("/one"),
                tab: NavigationTab(
                    name: "Annonser",
                    icon: "tab_search",
                    selectedIcon: "tab_search_selected"
                )
            ),
            NavigationSession(
                name: "tab2",
                path: NavigationPath("/two"),
                tab: NavigationTab(
                    name: "Sparade",
                    icon: "tab_favorite",
                    selectedIcon: "tab_favorite_selected"
                )
            ),
        ]
        var state = NavigationState(sessions: sessions)
        // Push a new view in a new session (Simulates a presented view)

        state = navigationReducer(
            action: NavigationActions.Push(
                path: NavigationPath("/presented"),
                target: "newSession"
            ),
            state: state
        )

        XCTAssertEqual(state.sessions.count, 3)

        let presentedSession = state.sessions.last!
        XCTAssertEqual(presentedSession.nextPath.path, "/presented")
        XCTAssertEqual(state.selectedSessionId, presentedSession.id)

        // Dismiss the session
        state = navigationReducer(
            action: NavigationActions.SessionDismissed(
                session: presentedSession
            ),
            state: state
        )

        XCTAssertEqual(state.sessions.count, 2)
        let lastSession = state.sessions.last!
        XCTAssertNotEqual(lastSession.id, presentedSession.id)
    }
}
