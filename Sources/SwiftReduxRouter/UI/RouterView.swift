import SwiftUI
import UIKit

/**
 RouterView provides a SwiftUI view to a navigationState
 */
public struct RouterView: UIViewControllerRepresentable {
    /// A Push action including the path with the dismissActionIdentifier will trigger the open vc to dismiss.
    public static let dismissActionIdentifier = ":dismiss"

    /// The navigationState
    @ObservedObject private var navigationState: NavigationState

    /// The root controller of the router

    /// Available routes
    private var routes: [Route]

    /// setSelectedPath is invoked by the UIViewController when it is in screen
    private var setSelectedPath: (NavigationSession, NavigationPath) -> Void

    /// onDismiss is invoked when the UIViewController will be dismissed
    private var onDismiss: (NavigationSession) -> Void

    /// setSelectedPath is invoked by the UIViewController when it is in screen
    private var sessionHasApplicant: (NavigationSession, NavigationPath) -> Void

    private var standaloneRouter: Router?

    private var tintColor: UIColor?
    /// Public init
    public init(
        navigationState: NavigationState,
        routes: [Route],
        tintColor: UIColor? = nil,
        setSelectedPath: @escaping (NavigationSession, NavigationPath) -> Void,
        onDismiss: @escaping (NavigationSession) -> Void,
        sessionHasApplicant: @escaping (NavigationSession, NavigationPath) -> Void,

        standaloneRouter: Router? = nil
    ) {
        self.navigationState = navigationState
        self.routes = routes
        self.setSelectedPath = setSelectedPath
        self.onDismiss = onDismiss
        self.standaloneRouter = standaloneRouter
        self.tintColor = tintColor
        self.sessionHasApplicant = sessionHasApplicant
    }

    // MARK: UIVIewControllerRepresentable methods

    public func makeUIViewController(context _: Context) -> UIViewController {
        return recreateViewControllerBasedOnState()
    }

    public func updateUIViewController(_ vc: UIViewController, context _: Context) {
        _ = recreateViewControllerBasedOnState(rootController: vc)
    }

    // MARK: Router methods

    private func asTabBarController(_ controller: UIViewController?) -> UITabBarController {
        guard let crlr = controller as? UITabBarController else {
            return UITabBarController()
        }
        return crlr
    }

    private func asNavigationController(_ controller: UIViewController?) -> NavigationController {
        guard let crlr = controller as? NavigationController else {
            return NavigationController()
        }
        return crlr
    }

    private func recreateViewControllerBasedOnState(rootController: UIViewController? = nil) -> UIViewController {
        // Appear as a tabbar. Initial state has more than one session
        if navigationState.sessions.filter({ $0.tab != nil }).count > 1 {
            let tc = asTabBarController(rootController)
            if let tintColor = tintColor {
                tc.tabBar.tintColor = tintColor
            }
            var ncs = [NavigationController]()
            var presentedControllers = [NavigationController]()
            for session in navigationState.sessions {
                let nc: NavigationController = tc.viewControllers?.compactMap { $0 as? NavigationController }.first(where: { $0.session?.id == session.id }) ??
                    findPresented(session: session, in: tc) ??
                    NavigationController()

                recreateSession(nc: nc, session: session)

                if let tab = session.tab {
                    if
                        navigationState.selectedSessionId == session.id,
                        let selectedIndex = navigationState.sessions.firstIndex(where: { $0.id == session.id })
                    {
                        tc.selectedIndex = selectedIndex
                    }

                    var icon: UIImage?
                    var selectedImage: UIImage?

                    if let selectedIcon = tab.selectedIcon {
                        switch selectedIcon {
                        case let .local(name):
                            selectedImage = UIImage(named: name)
                        case let .system(name: name):
                            selectedImage = UIImage(systemName: name)
                        }
                    }

                    switch tab.icon {
                    case let .local(name):
                        icon = UIImage(named: name)
                    case let .system(name: name):
                        icon = UIImage(systemName: name)
                    }

                    nc.tabBarItem = UITabBarItem(
                        title: tab.name,
                        image: icon,
                        selectedImage: selectedImage == nil ? icon : selectedImage
                    )
                    ncs.append(nc)
                    continue
                }

                presentedControllers.append(nc)
            }
            tc.setViewControllers(ncs, animated: false)

            if let presentedViewController = tc.presentedViewController as? NavigationController {
                removePresentedRedundancy(of: presentedViewController, in: presentedControllers) {
                    presentViewControllers(rootViewController: tc, ncs: presentedControllers) {}
                }
            } else {
                presentViewControllers(rootViewController: tc, ncs: presentedControllers) {}
            }

            return tc

            // Appear as a NavigationController. Initial state has only one session
        } else {
            let rnc = asNavigationController(rootController)
            guard let session = navigationState.sessions.first else { return rnc }

            rnc.session = session
            rnc.willShow = setSelectedPath
            rnc.onDismiss = onDismiss

            recreateSession(nc: rnc, session: session)

            var presentedControllers = [NavigationController]()
            for session in navigationState.sessions.filter({ $0.id != rnc.session?.id }) {
                let nc: NavigationController = findPresented(session: session, in: rnc) ??
                    NavigationController()

                recreateSession(nc: nc, session: session)

                presentedControllers.append(nc)
            }

            if let presentedViewController = rnc.presentedViewController as? NavigationController {
                removePresentedRedundancy(of: presentedViewController, in: presentedControllers) {
                    presentViewControllers(rootViewController: rnc, ncs: presentedControllers) {}
                }
            } else {
                presentViewControllers(rootViewController: rnc, ncs: presentedControllers) {}
            }

            return rnc
        }
    }

    private func recreateSession(nc: NavigationController, session: NavigationSession) {
        nc.session = session
        nc.willShow = setSelectedPath
        nc.onDismiss = onDismiss

        let vcs = session.presentedPaths.compactMap { path in
            nc.viewControllers.compactMap { $0 as? UIRouteViewController }.first(where: { $0.navigationPath?.id == path.id }) ?? getViewByPath(session, navigationPath: path)
        }

        nc.setViewControllers(vcs, animated: !navigationState.hasPresentedSessions)
    }

    private func findPresented(session: NavigationSession, in rootViewController: UIViewController) -> NavigationController? {
        var controller: NavigationController?
        if let presentedViewController = rootViewController.presentedViewController as? NavigationController {
            if presentedViewController.session?.id == session.id {
                return presentedViewController
            }
            controller = findPresented(session: session, in: presentedViewController)
        }
        return controller
    }

    private func findAllPresentedControllers(in rootViewController: NavigationController) -> [NavigationController] {
        var viewControllers = [NavigationController]()

        viewControllers.append(rootViewController)

        if let presentedViewController = rootViewController.presentedViewController as? NavigationController {
            viewControllers.append(contentsOf: findAllPresentedControllers(in: presentedViewController))
        }
        return viewControllers
    }

    private func removePresentedRedundancy(of rootViewController: NavigationController, in presentedControllers: [NavigationController], completion: @escaping () -> Void) {
        let ncs = Array(findAllPresentedControllers(in: rootViewController).reversed())
        dismiss(in: ncs, at: 0, completion: completion)
    }

    private func dismiss(in controllers: [NavigationController], at index: Int, completion: @escaping () -> Void) {
        guard index < controllers.count else {
            return completion()
        }

        let controller = controllers[index]

        if
            navigationState.sessions.firstIndex(where: { $0.id == controller.session?.id }) == nil
        {
            controller.dismiss(animated: true) {
                dismiss(in: controllers, at: index + 1, completion: completion)
            }
        } else {
            dismiss(in: controllers, at: index + 1, completion: completion)
        }
    }

    private func presentViewControllers(rootViewController: UIViewController, ncs: [NavigationController], completion: @escaping () -> Void) {
        var topController = rootViewController

        for controller in ncs {
            if
                let ctrl = topController.presentedViewController as? NavigationController,
                ctrl.session?.id == controller.session?.id
            {
                topController = ctrl

            } else {
                topController.present(controller, animated: true)
                topController = controller
            }
        }
    }

    // MARK: NavigationPath methods

    public func getViewByPath(_ session: NavigationSession, navigationPath: NavigationPath) -> UIRouteViewController? {
        let patterns = routes.map { $0.route.path }
        if
            let match = URLMatcher().match(navigationPath.path, from: patterns),
            let route = routes.first(where: { $0.route.path == match.pattern })
        {
            let vc: UIRouteViewController?
            if let render = route.renderView {
                let view = render(session, match.values, standaloneRouter)
                vc = RouteViewController(rootView: view)
            } else if let renderController = route.renderController {
                vc = renderController(session, match.values, standaloneRouter)
            } else {
                vc = RouteViewController(rootView: AnyView(EmptyView()))
            }
            guard let viewController = vc else {
                return nil
            }
            viewController.session = session
            viewController.navigationPath = navigationPath
            route.onWillAppear?(session.selectedPath, match.values)
            return viewController
        }

        return nil
    }
}

// MARK: Nested models

public extension RouterView {
    struct Route {
        public var route: NavigationRoute
        public var onWillAppear: ((_ path: NavigationPath, _ values: [String: Any]) -> Void)?
        public var renderView: ((_ session: NavigationSession, _ params: [String: Any], _ router: Router?) -> AnyView)?
        public var renderController: ((_ session: NavigationSession, _ params: [String: Any], _ router: Router?) -> UIRouteViewController?)?

        public init(
            route: NavigationRoute,
            onWillAppear: ((NavigationPath, [String: Any]) -> Void)? = nil,
            renderView: ((_ session: NavigationSession, _ params: [String: Any], _ router: Router?) -> AnyView)? = nil,
            renderController: ((_ session: NavigationSession, _ params: [String: Any], _ router: Router?) -> UIRouteViewController?)? = nil
        ) {
            self.route = route
            self.onWillAppear = onWillAppear
            self.renderView = renderView
            self.renderController = renderController
        }
    }
}
