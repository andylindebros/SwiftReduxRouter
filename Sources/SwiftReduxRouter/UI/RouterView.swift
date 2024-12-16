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
    @MainActor public struct RouterView: UIViewControllerRepresentable {
        /// Public init
        public init(
            navigationState: Navigation.State,
            tabBarController: TabControllerProvider? = nil,
            routes: [Route],
            tintColor: UIColor? = nil,
            tabBarIconImages: [NavigationTab.IconImage]? = nil,
            dispatch: @escaping NavigationDispatcher
        ) {
            self.navigationState = navigationState
            self.tabBarController = tabBarController
            self.routes = routes
            self.tabBarIconImages = tabBarIconImages
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
        }

        private let tabBarController: TabControllerProvider?

        /// The navigationState
        private var navigationState: Navigation.State

        /// Available routes
        private let routes: [Route]

        /// setSelectedPath is invoked by the UIViewController when it is in screen
        private let setSelectedPath: (NavigationModel, NavPath) -> Void

        /// onDismiss is invoked when the UIViewController will be dismissed
        private let onDismiss: (NavigationModel) -> Void
        private let selectedDetentDidChange: (String, NavigationModel) -> Void

        private let dispatch: NavigationDispatcher

        private let tintColor: UIColor?

        private let tabBarIconImages: [NavigationTab.IconImage]?

        // MARK: UIVIewControllerRepresentable methods

        public func makeUIViewController(context _: Context) -> UIViewController {
            return recreateViewControllerBasedOnState()
        }

        public func updateUIViewController(_ vc: UIViewController, context _: Context) {
            recreateViewControllerBasedOnState(rootController: vc)
        }

        // MARK: Router methods

        private func asTabBarController(_ controller: UIViewController?) -> TabControllerProvider {
            guard let crlr = controller as? TabControllerProvider else {
                let tc = tabBarController ?? TabController()
                tc.onTabAlreadySelected = { navPath in
                    dispatch(NavigationAction.shouldScrollToTop(navPath))
                }
                return tc
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
            if navigationState.observed.navigationModels.filter({ $0.tab != nil }).count > 1 {
                let tc = asTabBarController(rootController)

                if let tintColor = tintColor {
                    tc.tabBar.tintColor = tintColor
                }
                var ncs = [NavigationController]()
                var presentedControllers = [NavigationController]()
                for navigationModel in navigationState.observed.navigationModels {
                    let nc: NavigationController = tc.viewControllers?.compactMap { $0 as? NavigationController }.first(where: { $0.navigationModel?.id == navigationModel.id }) ??
                        findPresented(navigationModel: navigationModel, in: tc) ?? NavigationController()

                    recreateNavigation(nc: nc, navigationModel: navigationModel)

                    if let tab = navigationModel.tab {
                        if
                            navigationState.observed.rootSelectedModelID == navigationModel.id,
                            let selectedIndex = navigationState.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
                        {
                            tc.selectedIndex = selectedIndex
                        }

                        var icon: UIImage?
                        var selectedImage: UIImage?

                        if let selectedIcon = tab.selectedIcon {
                            switch selectedIcon {
                            case let .iconImage(id: id):
                                if let image = tabBarIconImages?.first(where: { $0.id == id })?.image {
                                    selectedImage = image
                                }
                            case let .local(name):
                                selectedImage = UIImage(named: name)
                            case let .system(name: name):
                                selectedImage = UIImage(systemName: name)
                            }
                        }

                        switch tab.icon {
                        case let .iconImage(id: id):
                            if let image = tabBarIconImages?.first(where: { $0.id == id })?.image {
                                icon = image
                            }
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

                        if let badgeColor = tab.badgeColor {
                            nc.tabBarItem.badgeColor = badgeColor
                        }
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
                guard let navigationModel = navigationState.observed.navigationModels.first else { return rnc }

                rnc.navigationModel = navigationModel
                rnc.willShow = setSelectedPath
                rnc.onDismiss = onDismiss
                rnc.selectedDetentDidChange = selectedDetentDidChange

                recreateNavigation(nc: rnc, navigationModel: navigationModel)

                var presentedControllers = [NavigationController]()
                for navigationModel in navigationState.observed.navigationModels.filter({ $0.id != rnc.navigationModel?.id }) {
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
                if let vc = nc.viewControllers.compactMap({ $0 as? UIRouteViewController }).first(where: { $0.viewModel?.path.id == path.id }) {
                    if vc.viewModel?.path.url != path.url {
                        Task {
                            await vc.viewModel?.setPath(to: path)
                        }
                    }
                    return vc
                }

                return Self.view(for: path, in: navigationModel, andInRoutes: routes)
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
                controller.isDismissing == false,
                navigationState.observed.navigationModels.first(where: { $0.id == controller.navigationModel?.id }) == nil || navigationState.observed.navigationModels.first(where: { $0.id == controller.navigationModel?.id })?.shouldBeDismsised == true
            {
                controller.isDismissing = true
                controller.dismiss(animated: controller.navigationModel?.animate ?? true) {
                    if let removalModel = controller.navigationModel {
                        DispatchQueue.main.async {
                            dispatch(NavigationAction.dismiss(.navigationModel(removalModel)))
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

            if let alertModel = navigationState.observed.alerts.first {
                presentAlert(with: alertModel, in: topController)
            }
        }

        // MARK: NavPath methods

        static func view(for navigationPath: NavPath, in navigationModel: NavigationModel, andInRoutes routes: [Route]) -> UIRouteViewController? {
            guard
                let (route, urlMatchResult) = Self.route(for: navigationPath, in: routes),
                let route = route
            else {
                return nil
            }

            let vc =  viewController(of: route, with: urlMatchResult, for: navigationPath, in: navigationModel)

            if let vc {
                return vc
            } else if let defaultRoute = Self.defaultRoute(in: routes), let defaultVc = viewController(of: defaultRoute, with: urlMatchResult, for: navigationPath, in: navigationModel) {
                return defaultVc
            } else {
                return RouteViewController(rootView: EmptyView())
            }
        }

        private static func route(for navigationPath: NavPath, in routes: [Route]) -> (Route?, URLMatchResult?)? {
            let patterns = routes.flatMap { $0.paths.map { $0.path } }

            guard
                let path = navigationPath.path,
                let urlMatchResult = URLMatcher().match(path, from: patterns),
                let route = routes.filter({ $0.paths.first { $0.path == urlMatchResult.pattern } != nil }).first
            else {
                // provide first
                return (Self.defaultRoute(in: routes), nil)
            }

            guard route.validate(urlMatchResult) else {
                return nil
            }
            return (route, urlMatchResult)
        }

        private static func defaultRoute(in routes: [Route]) -> Route? {
            routes.first { $0.defaultRoute }
        }

        private static func viewController(
            of route: Route,
            with matchResult: URLMatchResult?,
            for navigationPath: NavPath,
            in navigationModel: NavigationModel
        ) -> UIRouteViewController? {
            let viewModel = RouteViewModel(
                path: navigationPath.setMatchResultIfNeeded(to: matchResult),
                navigationModel: navigationModel
            )
            if let view = route.render?(viewModel) {
                view.viewModel = viewModel
                return view
            }
            return nil
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
                render:  (@MainActor(RouteViewModel) -> UIRouteViewController?)? = nil,
                defaultRoute: Bool = false
            ) {
                self.paths = paths
                self.render = render
                self.defaultRoute = defaultRoute
            }

            public let paths: [NavigationRoute]
            public let render: (@MainActor(RouteViewModel) -> UIRouteViewController?)?
            public let defaultRoute: Bool

            func validate(_ result: URLMatchResult) -> Bool {
                guard
                    let path = paths.first(where: { $0.path == result.pattern })
                else {
                    return false
                }

                return path.validate(result: result, forAccessLevel: .private)
            }
        }
    }

    public extension RouterView {
        struct NavigationControllerRoute {
            public init(paths: [NavigationRoute], render: @escaping (NavigationModel, [String: URLPathMatchValue]?) -> NavigationController) {
                self.paths = paths
                self.render = render
            }

            public let paths: [NavigationRoute]
            public let render: (
                NavigationModel,
                [String: URLPathMatchValue]?
            ) -> NavigationController
        }
    }

#endif
