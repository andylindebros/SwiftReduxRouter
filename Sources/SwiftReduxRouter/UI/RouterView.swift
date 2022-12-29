import SwiftUI
import UIKit

/**
 RouterView provides a SwiftUI view to a navigationState
 */
@available(iOS 13, *)
public struct RouterView: UIViewControllerRepresentable {
    /// A Push action including the path with the dismissActionIdentifier will trigger the open vc to dismiss.
    public static let dismissActionIdentifier = ":dismiss"

    /// The navigationState
    @ObservedObject private var navigationState: NavigationState

    /// The root controller of the router

    /// Available routes
    private var routes: [Route]

    /// setSelectedPath is invoked by the UIViewController when it is in screen
    private var setSelectedPath: (NavigationModel, NavigationPath) -> Void

    /// onDismiss is invoked when the UIViewController will be dismissed
    private var onDismiss: (NavigationModel) -> Void

    private var tintColor: UIColor?

    /// Public init
    public init(
        navigationState: NavigationState,
        routes: [Route],
        tintColor: UIColor? = nil,
        setSelectedPath: @escaping (NavigationModel, NavigationPath) -> Void,
        onDismiss: @escaping (NavigationModel) -> Void
    ) {
        self.navigationState = navigationState
        self.routes = routes
        self.setSelectedPath = setSelectedPath
        self.onDismiss = onDismiss
        self.tintColor = tintColor
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
        // Appear as a tabbar. Initial state has more than one navigationModel
        if navigationState.navigationModels.filter({ $0.tab != nil }).count > 1 {
            let tc = asTabBarController(rootController)
            if let tintColor = tintColor {
                tc.tabBar.tintColor = tintColor
            }
            var ncs = [NavigationController]()
            var presentedControllers = [NavigationController]()
            for navigationModel in navigationState.navigationModels {
                let nc: NavigationController = tc.viewControllers?.compactMap { $0 as? NavigationController }.first(where: { $0.navigationModel?.id == navigationModel.id }) ??
                    findPresented(navigationModel: navigationModel, in: tc) ??
                    NavigationController()

                recreateNavigation(nc: nc, navigationModel: navigationModel)

                if let tab = navigationModel.tab {
                    if
                        navigationState.rootSelectedModelID == navigationModel.id,
                        let selectedIndex = navigationState.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
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

                    nc.tabBarItem.badgeColor = tab.badgeColor ?? .red
                    nc.tabBarItem.badgeValue = tab.badgeValue
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

            // Appear as a NavigationController. Initial state has only one navigationModel
        } else {
            let rnc = asNavigationController(rootController)
            guard let navigationModel = navigationState.navigationModels.first else { return rnc }

            rnc.navigationModel = navigationModel
            rnc.willShow = setSelectedPath
            rnc.onDismiss = onDismiss

            recreateNavigation(nc: rnc, navigationModel: navigationModel)

            var presentedControllers = [NavigationController]()
            for navigationModel in navigationState.navigationModels.filter({ $0.id != rnc.navigationModel?.id }) {
                let nc: NavigationController = findPresented(navigationModel: navigationModel, in: rnc) ??
                    NavigationController()

                recreateNavigation(nc: nc, navigationModel: navigationModel)

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

    private func recreateNavigation(nc: NavigationController, navigationModel: NavigationModel) {
        nc.navigationModel = navigationModel
        nc.willShow = setSelectedPath
        nc.onDismiss = onDismiss

        let vcs = navigationModel.presentedPaths.compactMap { path in
            nc.viewControllers.compactMap { $0 as? UIRouteViewController }.first(where: { $0.navigationPath?.id == path.id }) ?? Self.view(for: path, in: navigationModel, andInRoutes: routes)
        }

        nc.setViewControllers(vcs, animated: navigationModel.animate && nc.presentedViewController == nil)
    }

    private func findPresented(navigationModel: NavigationModel, in rootViewController: UIViewController) -> NavigationController? {
        var controller: NavigationController?
        if let presentedViewController = rootViewController.presentedViewController as? NavigationController {
            if presentedViewController.navigationModel?.id == navigationModel.id {
                return presentedViewController
            }
            controller = findPresented(navigationModel: navigationModel, in: presentedViewController)
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
            navigationState.navigationModels.firstIndex(where: { $0.id == controller.navigationModel?.id }) == nil
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
                ctrl.navigationModel?.id == controller.navigationModel?.id {
                topController = ctrl

            } else {
                topController.present(controller, animated: true)
                topController = controller
            }
        }
    }

    // MARK: NavigationPath methods

    static func view(for navigationPath: NavigationPath, in navigationModel: NavigationModel, andInRoutes routes: [Route]) -> UIRouteViewController? {
        guard
            let (route, urlMatchResult) = Self.route(for: navigationPath, in: routes),
            let route = route
        else {
            return nil
        }

        let viewController = viewController(of: route, with: urlMatchResult, for: navigationPath, in: navigationModel)

        viewController.navigationModel = navigationModel
        viewController.navigationPath = navigationPath

        return viewController
    }

    private static func route(for navigationPath: NavigationPath, in routes: [Route]) -> (Route?, URLMatchResult?)? {
        let patterns = routes.flatMap { $0.paths.map { $0.path } }

        guard
            let urlMatchResult = URLMatcher().match(navigationPath.path, from: patterns),
            let route = routes.filter({ $0.paths.first { $0.path == urlMatchResult.pattern } != nil }).first
        else {
            // provide first
            return (Self.defaultRoute(in: routes), nil)
        }

        return (route, urlMatchResult)
    }

    private static func defaultRoute(in routes: [Route]) -> Route? {
        routes.first { $0.defaultRoute }
    }

    private static func viewController(
        of route: Route,
        with urlMatchResult: URLMatchResult?,
        for navigationPath: NavigationPath,
        in navigationModel: NavigationModel
    ) -> UIRouteViewController {
        if let view = route.renderView?(navigationPath, navigationModel, urlMatchResult?.values) {
            return RouteViewController(
                rootView: view,
                hideNavigationBar: navigationPath.hideNavigationBar,
                title: navigationPath.title
            )

        } else if let view = route.renderController?(navigationPath, navigationModel, urlMatchResult?.values) {
            return view
        } else {
            return RouteViewController(rootView: AnyView(EmptyView()))
        }
    }
}

// MARK: Nested models

@available(iOS 13, *)
public extension RouterView {
    struct Route {
        public var paths: [NavigationRoute]
        public var onWillAppear: ((NavigationPath, [String: Any]?) -> Void)?
        public var renderView: ((NavigationPath, NavigationModel, [String: Any]?) -> AnyView?)?
        public var renderController: ((NavigationPath, NavigationModel, [String: Any]?) -> UIRouteViewController?)?
        public var defaultRoute: Bool
        public init(
            paths: [NavigationRoute],
            onWillAppear: ((NavigationPath, [String: Any]?) -> Void)? = nil,
            renderView: ((NavigationPath, NavigationModel, [String: Any]?) -> AnyView?)? = nil,
            renderController: ((NavigationPath, NavigationModel, [String: Any]?) -> UIRouteViewController?)? = nil,
            defaultRoute: Bool = false
        ) {
            self.paths = paths
            self.onWillAppear = onWillAppear
            self.renderView = renderView
            self.renderController = renderController
            self.defaultRoute = defaultRoute
        }
    }
}
