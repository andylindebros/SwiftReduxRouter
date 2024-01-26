import Combine
import SwiftUI
#if os(iOS)
    import UIKit
#endif
#if canImport(UIKit)
    /**
     RouterView provides a SwiftUI view to a navigationState
     */
    @available(iOS 13, *)
    public struct RouterView: UIViewControllerRepresentable {
        /// Public init
        public init(
            navigationState: NavigationState,
            navigationControllerRoutes: [NavigationControllerRoute] = [],
            routes: [Route],
            tintColor: UIColor? = nil,
            dispatch: @escaping NavigationDispatcher
        ) {
            self.navigationState = navigationState
            self.routes = routes
            self.navigationControllerRoutes = navigationControllerRoutes
            self.tintColor = tintColor
            self.dispatch = dispatch

            setSelectedPath = { model, path in
                dispatch(NavigationAction.setSelectedPath(to: path, in: model))
            }
            onDismiss = { navigationModel in
                dispatch(NavigationAction.setNavigationDismsissed(navigationModel))
            }

            selectedDetentDidChange = { identifier, navigationModel in
                dispatch(NavigationAction.selectedDetentChanged(to: identifier, in: navigationModel))
            }

            navigationState
                .setAvailableRoutes(routes.map { $0.paths }.flatMap { $0 })
                .setAvailableNavigationRoutes(navigationControllerRoutes.map { $0.paths }.flatMap { $0 })
        }

        /// The navigationState
        @ObservedObject private var navigationState: NavigationState

        /// Available routes
        private let routes: [Route]

        /// Available navigationControllerRoutes
        private let navigationControllerRoutes: [NavigationControllerRoute]

        /// setSelectedPath is invoked by the UIViewController when it is in screen
        private let setSelectedPath: (NavigationModel, NavigationPath) -> Void

        /// onDismiss is invoked when the UIViewController will be dismissed
        private let onDismiss: (NavigationModel) -> Void
        private let selectedDetentDidChange: (String, NavigationModel) -> Void

        private let dispatch: NavigationDispatcher

        private let tintColor: UIColor?

        // MARK: UIVIewControllerRepresentable methods

        public func makeUIViewController(context _: Context) -> UIViewController {
            return recreateViewControllerBasedOnState()
        }

        public func updateUIViewController(_ vc: UIViewController, context _: Context) {
            recreateViewControllerBasedOnState(rootController: vc)
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

        @discardableResult private func recreateViewControllerBasedOnState(rootController: UIViewController? = nil) -> UIViewController {
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
                        Self.navigationController(for: navigationModel, in: navigationControllerRoutes)

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
                            case let .fileName(fileName):
                                selectedImage = UIImage(contentsOfFile: fileName)
                            case let .local(name):
                                selectedImage = UIImage(named: name)
                            case let .system(name: name):
                                selectedImage = UIImage(systemName: name)
                            }
                        }

                        switch tab.icon {
                        case let .fileName(fileName):
                            icon = UIImage(contentsOfFile: fileName)
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
                rnc.selectedDetentDidChange = selectedDetentDidChange

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
            nc.selectedDetentDidChange = selectedDetentDidChange

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

        private func removePresentedRedundancy(of rootViewController: NavigationController, in _: [NavigationController], completion: @escaping () -> Void) {
            let ncs = Array(findAllPresentedControllers(in: rootViewController).reversed())
            dismiss(in: ncs, at: 0, completion: completion)
        }

        private func dismiss(in controllers: [NavigationController], at index: Int, completion: @escaping () -> Void) {
            guard index < controllers.count else {
                return completion()
            }

            let controller = controllers[index]

            if
                navigationState.navigationModels.first(where: { $0.id == controller.navigationModel?.id }) == nil || navigationState.navigationModels.first(where: { $0.id == controller.navigationModel?.id })?.shouldBeDismsised == true
            {
                controller.dismiss(animated: controller.navigationModel?.animate ?? true) {
                    if let removalModel = controller.navigationModel {
                        DispatchQueue.main.async {
                            dispatch(NavigationAction.dismiss(removalModel))
                        }
                    }
                    if let completionAction = controller.navigationModel?.dismissCompletionAction {
                        DispatchQueue.main.async {
                            dispatch(completionAction)
                        }
                    }
                    dismiss(in: controllers, at: index + 1, completion: completion)
                }
            } else {
                dismiss(in: controllers, at: index + 1, completion: completion)
            }
        }

        private func presentViewControllers(rootViewController: UIViewController, ncs: [NavigationController], completion _: @escaping () -> Void) {
            var topController = rootViewController

            for controller in ncs {
                if
                    let ctrl = topController.presentedViewController as? NavigationController,
                    ctrl.navigationModel?.id == controller.navigationModel?.id
                {
                    topController = ctrl
                    if #available(iOS 16.0, *), let selectedDetentIdentifier = controller.navigationModel?.selectedDetentIdentifier, let sheet = controller.sheetPresentationController,
                       sheet.detents.map({ $0.identifier.rawValue }).contains(selectedDetentIdentifier),
                       sheet.selectedDetentIdentifier?.rawValue != selectedDetentIdentifier
                    {
                        sheet.animateChanges {
                            sheet.selectedDetentIdentifier = UISheetPresentationController.Detent.Identifier(rawValue: selectedDetentIdentifier)
                        }
                    }
                } else {
                    guard (controller.navigationModel?.shouldBeDismsised ?? false) == false else {
                        continue
                    }
                    controller.modalPresentationStyle = controller.navigationModel?.presentationType.style ?? .automatic

                    if controller.navigationModel?.presentationType.preventDismissal == true {
                        controller.isModalInPresentation = true
                    }

                    if let type = controller.navigationModel?.presentationType, case let PresentationType.detents(detents, selectedDetent, largestUndimmedDetentIdentifier, _, prefersGrabberVisible, preferredCornerRadius, prefersScrollingExpandsWhenScrolledToEdge) = type, let sheet = controller.sheetPresentationController {
                        sheet.prefersGrabberVisible = prefersGrabberVisible
                        if let preferredCornerRadius = preferredCornerRadius {
                            sheet.preferredCornerRadius = preferredCornerRadius
                        }
                        sheet.detents = Array(Set(detents.map { $0.detent }))
                        sheet.prefersEdgeAttachedInCompactHeight = true

                        if #available(iOS 16.0, *), let selectedDetent = selectedDetent {
                            sheet.selectedDetentIdentifier = selectedDetent.detent.identifier
                        }

                        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
                        sheet.prefersScrollingExpandsWhenScrolledToEdge = prefersScrollingExpandsWhenScrolledToEdge
                        if #available(iOS 16.0, *), let largestUndimmedDetentIdentifier = largestUndimmedDetentIdentifier?.detent.identifier {
                            sheet.largestUndimmedDetentIdentifier = largestUndimmedDetentIdentifier
                        }
                    }
                    topController.present(controller, animated: controller.navigationModel?.animate ?? true)
                    topController = controller
                }
            }

            if let alertModel = navigationState.alerts.first {
                presentAlert(with: alertModel, in: topController)
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

            DispatchQueue.main.async {
                route.onDidAppear?(navigationPath, navigationModel, urlMatchResult?.values)
            }
            return viewController
        }

        private static func route(for navigationPath: NavigationPath, in routes: [Route]) -> (Route?, URLMatchResult?)? {
            let patterns = routes.flatMap { $0.paths.map { $0.path } }

            guard
                let path = navigationPath.path,
                let urlMatchResult = URLMatcher().match(path, from: patterns),
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
            if let view = route.render?(navigationPath, navigationModel, urlMatchResult?.values) {
                return view
            } else {
                return RouteViewController(rootView: EmptyView())
            }
        }
    }

    extension RouterView {
        func presentAlert(with model: AlertModel, in viewController: UIViewController) {
            let alert = UIAlertController(title: model.title, message: model.message, preferredStyle: model.type)

            for button in model.buttons ?? [.init(label: "OK")] {
                alert.addAction(UIAlertAction(title: button.label, style: button.type) { _ in
                    dispatch(NavigationAction.dismissedAlert(with: model))
                    if let actions = button.actions {
                        for action in actions {
                            dispatch(action)
                        }
                    }
                })
            }

            viewController.present(alert, animated: true)
        }
    }

    // MARK: Nested models

    @available(iOS 13, *)
    public extension RouterView {
        struct Route {
            public init(
                paths: [NavigationRoute],
                onDidAppear: ((NavigationPath, NavigationModel, [String: Any]?) -> Void)? = nil,
                render: ((NavigationPath, NavigationModel, [String: Any]?) -> UIRouteViewController?)? = nil,
                defaultRoute: Bool = false
            ) {
                self.paths = paths
                self.onDidAppear = onDidAppear
                self.render = render
                self.defaultRoute = defaultRoute
            }

            public let paths: [NavigationRoute]
            public let onDidAppear: ((NavigationPath, NavigationModel, [String: Any]?) -> Void)?
            public let render: ((NavigationPath, NavigationModel, [String: Any]?) -> UIRouteViewController?)?
            public let defaultRoute: Bool
        }
    }

    public extension RouterView {
        struct NavigationControllerRoute {
            public init(paths: [NavigationRoute], render: @escaping (NavigationModel, [String: Any]?) -> NavigationController) {
                self.paths = paths
                self.render = render
            }

            public let paths: [NavigationRoute]
            public let render: (NavigationModel, [String: Any]?) -> NavigationController
        }
    }

    private extension RouterView {
        static func navigationController(for navigationModel: NavigationModel, in routes: [NavigationControllerRoute]) -> NavigationController {
            guard
                let (route, urlMatchResult) = Self.navigationControllerRoute(for: navigationModel, in: routes),
                let route = route
            else {
                return NavigationController()
            }

            return route.render(navigationModel, urlMatchResult?.values)
        }

        static func navigationControllerRoute(for navigationModel: NavigationModel, in routes: [NavigationControllerRoute]) -> (NavigationControllerRoute?, URLMatchResult?)? {
            let patterns = routes.flatMap { $0.paths.map { $0.path } }

            guard
                let path = navigationModel.path?.path,
                let urlMatchResult = URLMatcher().match(path, from: patterns),
                let route = routes.filter({ $0.paths.first { $0.path == urlMatchResult.pattern } != nil }).first
            else {
                return nil
            }

            return (route, urlMatchResult)
        }
    }
#endif
