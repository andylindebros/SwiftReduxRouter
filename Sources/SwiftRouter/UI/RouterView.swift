import Combine
import SwiftUI
#if os(iOS)
    import UIKit

    public extension SwiftRouter {
        // swiftlint:disable opening_brace
        /**
         RouterView provides a SwiftUI view based on a navigation state
         */
        struct RouterView: UIViewControllerRepresentable {
            /// Public init
            public init(
                navigationState: State,
                tabBarController: TabControllerProvider? = nil,
                routes: [RouterView.Config],
                tintColor: UIColor? = nil,
                tabBarIconImages: [Tab.IconImage]? = nil,
                dispatch: @escaping NavigationDispatcher
            ) {
                self.navigationState = navigationState
                self.tabBarController = tabBarController
                self.routes = routes
                self.tabBarIconImages = tabBarIconImages
                self.tintColor = tintColor
                self.dispatch = dispatch

                setSelectedPath = { model, path in
                    dispatch(Action.setSelectedPath(to: path, in: model))
                }
                onDismiss = { navigationModel in
                    if navigationModel.isPresented {
                        dispatch(Action.setNavigationDismissed(navigationModel))
                    }
                }

                selectedDetentDidChange = { identifier, navigationModel in
                    dispatch(Action.selectedDetentIdentifierChanged(to: identifier, in: navigationModel))
                }
            }

            private let tabBarController: TabControllerProvider?

            /// The navigationState
            private var navigationState: State

            /// Available routes
            private let routes: [RouterView.Config]

            /// setSelectedPath is invoked by the UIViewController when it is in screen
            private let setSelectedPath: (Model, Path) -> Void

            /// onDismiss is invoked when the UIViewController will be dismissed
            private let onDismiss: (Model) -> Void
            private let selectedDetentDidChange: (String, Model) -> Void

            private let dispatch: NavigationDispatcher

            private let tintColor: UIColor?

            private let tabBarIconImages: [Tab.IconImage]?

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
                    return tabBarController ?? TabController()
                }
                return crlr
            }

            private func asNavigationController(_ controller: UIViewController?) -> Controller {
                guard let crlr = controller as? Controller else {
                    return Controller()
                }
                return crlr
            }

            // swiftlint:disable cyclomatic_complexity function_body_length
            @discardableResult private func recreateViewControllerBasedOnState(rootController: UIViewController? = nil) -> UIViewController {
                guard
                    navigationState.observed.navigationModels.contains(where: { $0.tab != nil })
                else {
                    fatalError("At least one tab must be implemented")
                }

                // Appear as a tabbar. Initial state has more than one navigationModel
                let tc = asTabBarController(rootController)

                if let tintColor = tintColor {
                    tc.tabBar.tintColor = tintColor
                }
                var ncs = [Controller]()
                var presentedControllers = [Controller]()
                var selectedTabIndex: Int?
                // Loop over navigationModels in the state
                for navigationModel in navigationState.observed.navigationModels {
                    // find matching navigationController or create new.
                    let nc: Controller = tc.viewControllers?.compactMap { $0 as? Controller }.first(where: { $0.navigationModel?.id == navigationModel.id }) ??
                        findPresented(navigationModel: navigationModel, in: tc) ?? Controller()

                    // setup navigationController based on navigationModel
                    recreateNavigation(nc: nc, navigationModel: navigationModel)

                    if let tab = navigationModel.tab {
                        if
                            navigationState.observed.rootSelectedModelID == navigationModel.id,
                            let selectedIndex = navigationState.observed.navigationModels.firstIndex(where: { $0.id == navigationModel.id })
                        {
                            selectedTabIndex = selectedIndex
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

                    // If navigationController was not added to the tabBar, treat it as a presented navigation controller
                    presentedControllers.append(nc)

                    if presentedControllers.count > 100 {
                        fatalError("Maximum amount of presented views exceeded (100).")
                    }
                }
                // Apply appropriate navigation controllers as tabs
                tc.setViewControllers(ncs, animated: false)

                if let selectedTabIndex {
                    tc.selectedIndex = selectedTabIndex
                }
                // Remove all untracked presented viewControllers and windows
                // A view that is added outside the navigationState is considered as untracked such as alerts, action sheets, windows etc.
                if navigationState.observed.removeUntrackedViews {
                    dismissPresentedViewsInOtherWindows()
                }

                if let presentedViewController = tc.presentedViewController {
                    // Remove all redundant presented view controllers and then present need viewControllers
                    removePresentedRedundancy(of: presentedViewController) {
                        presentViewControllers(rootViewController: tc, ncs: presentedControllers) {}
                    }
                } else {
                    presentViewControllers(rootViewController: tc, ncs: presentedControllers) {}
                }

                // Notify tabBarController to present tips if needed.
                if let tipIdentifier = navigationState.observed.tipIdentifier, let tipNavigationModelId = navigationState.observed.tipNavigationModelID, let tipNavigationModel = navigationState.observed.navigationModels.first(where: { $0.id == tipNavigationModelId }) {
                    Task { @MainActor in
                        tabBarController?.showTip(withID: tipIdentifier, withNavigationModel: tipNavigationModel)
                    }
                }

                // Notify state that untracked view removal has completed.
                if navigationState.observed.removeUntrackedViews {
                    dispatch(SwiftRouter.Action.untrackedViewsRemoved)
                }
                return tc
            }

            // swiftlint:enable cyclomatic_complexity function_body_length

            private func recreateNavigation(nc: Controller, navigationModel: Model) {
                // Update properties of NavigationController
                nc.navigationModel = navigationModel
                nc.willShow = setSelectedPath
                nc.onDismiss = onDismiss
                nc.selectedDetentDidChange = selectedDetentDidChange

                // Map presentedPaths to UIViewControllers
                let vcs = navigationModel.presentedPaths.compactMap { path in
                    if
                        let vc = nc.viewControllers.compactMap({ $0 as? UIRouteViewController }).first(where: { $0.viewModel?.path.id == path.id })
                    {
                        vc.viewModel?.setHasBeenShown(to: path.hasBeenShown)
                        vc.viewModel?.setModel(to: navigationModel)

                        if vc.viewModel?.path.url != path.url {
                            Task {
                                await vc.viewModel?.setPath(to: path)
                            }
                        }
                        return vc
                    }

                    // match and render new view for the viewController
                    return Self.view(for: path, in: navigationModel, andInRoutes: routes)
                }

                // Apply viewControllers to navigationContoller
                nc.setViewControllers(vcs, animated: (nc.viewControllers.count != vcs.count) && navigationModel.animate && nc.presentedViewController == nil)
            }

            private func findPresented(navigationModel: Model, in rootViewController: UIViewController, loopCount: Int = 0) -> Controller? {
                if loopCount > 100 {
                    fatalError("Maximum recursive loop exceeded (100).")
                }
                var controller: Controller?
                if let presentedViewController = rootViewController.presentedViewController as? Controller {
                    if presentedViewController.navigationModel?.id == navigationModel.id {
                        return presentedViewController
                    }
                    controller = findPresented(navigationModel: navigationModel, in: presentedViewController, loopCount: loopCount + 1)
                }
                return controller
            }

            private func dismissPresentedViewsInOtherWindows() {
                let dismissals = UIApplication.shared.getAllUIWindows()
                    .filter { ($0 as? SwiftRouter.Window) == nil }
                    .compactMap { $0 }
                for win in dismissals {
                    if let rootViewController = win.rootViewController {
                        rootViewController.dismiss(animated: true) {
                            win.windowScene = nil
                        }
                    } else {
                        win.windowScene = nil
                    }
                }
            }

            private func findAllPresentedControllers(in rootViewController: UIViewController, loopCount: Int = 0) -> [UIViewController] {
                if loopCount > 100 {
                    fatalError("Maximum recursive loop exceeded (100).")
                }
                var viewControllers = [rootViewController]

                if let presentedViewController = rootViewController.presentedViewController {
                    viewControllers.append(contentsOf: findAllPresentedControllers(in: presentedViewController, loopCount: loopCount + 1))
                }
                return viewControllers
            }

            private func removePresentedRedundancy(of rootViewController: UIViewController, completion: @escaping () -> Void) {
                let ncs = Array(findAllPresentedControllers(in: rootViewController).reversed())
                dismiss(in: ncs, at: 0, completion: completion)
            }

            private func dismiss(in controllers: [UIViewController], at index: Int, completion: @escaping () -> Void) {
                if index > 100 {
                    fatalError("Maximum recursive loop exceeded (100).")
                }
                guard index < controllers.count else {
                    return completion()
                }

                let controller = controllers[index]

                if let controller = controller as? Controller {
                    if
                        controller.isDismissing == false,

                        navigationState.observed.navigationModels.first(where: { $0.id == controller.navigationModel?.id }) == nil || navigationState.observed.navigationModels.first(where: { $0.id == controller.navigationModel?.id })?.shouldBeDismsised == true // swiftlint:disable:this contains_over_first_not_nil
                    {
                        controller.isDismissing = true
                        controller.dismiss(animated: controller.navigationModel?.animate ?? true) {
                            if let removalModel = controller.navigationModel {
                                DispatchQueue.main.async {
                                    dispatch(SwiftRouter.Action.dismiss(.model(removalModel)))
                                }
                            }
                            if let completion = controller.navigationModel?.dismissCompletionAction?.completion {
                                DispatchQueue.main.async {
                                    completion()
                                }
                            }
                            dismiss(in: controllers, at: index + 1, completion: completion)
                        }
                    } else {
                        dismiss(in: controllers, at: index + 1, completion: completion)
                    }
                } else if navigationState.observed.removeUntrackedViews {
                    controller.dismiss(animated: true) {
                        dismiss(in: controllers, at: index + 1, completion: completion)
                    }
                } else {
                    dismiss(in: controllers, at: index + 1, completion: completion)
                }
            }

            // swiftlint:disable cyclomatic_complexity function_body_length
            private func presentViewControllers(rootViewController: UIViewController, ncs: [Controller], completion _: @escaping () -> Void) {
                var topController = rootViewController

                for controller in ncs {
                    if
                        let ctrl = topController.presentedViewController as? Controller,
                        ctrl.navigationModel?.id == controller.navigationModel?.id
                    {
                        topController = ctrl

                        if
                            let type = controller.navigationModel?.presentationType,
                            case let Model.PresentationType.detents(model, _) = type,
                            let sheet = controller.sheetPresentationController
                        {
                            if let detent = model.largestUndimmedDetentIdentifier?.detent {
                                sheet.largestUndimmedDetentIdentifier = detent.identifier
                            }
                            if let current = sheet.preferredCornerRadius, let new = model.preferredCornerRadius, current != Double(new) {
                                sheet.preferredCornerRadius = Double(new)
                            }

                            if model.prefersGrabberVisible, sheet.prefersGrabberVisible != model.prefersGrabberVisible {
                                sheet.prefersGrabberVisible = model.prefersGrabberVisible
                            }

                            if model.prefersScrollingExpandsWhenScrolledToEdge, sheet.prefersScrollingExpandsWhenScrolledToEdge != model.prefersScrollingExpandsWhenScrolledToEdge {
                                sheet.prefersScrollingExpandsWhenScrolledToEdge = model.prefersScrollingExpandsWhenScrolledToEdge
                            }

                            sheet.detents = Array(Set(model.detents.map { $0.detent }))
                        }

                        if
                            let selectedDetentIdentifier = controller.navigationModel?.selectedDetentIdentifier,
                            let sheet = controller.sheetPresentationController,
                            sheet.detents.map({ $0.identifier.rawValue }).contains(selectedDetentIdentifier),
                            sheet.selectedDetentIdentifier?.rawValue != selectedDetentIdentifier
                        {
                            DispatchQueue.main.async {
                                sheet.animateChanges {
                                    sheet.selectedDetentIdentifier = UISheetPresentationController.Detent.Identifier(rawValue: selectedDetentIdentifier)
                                }
                            }
                        }
                    } else {
                        guard (controller.navigationModel?.shouldBeDismsised ?? false) == false else {
                            continue
                        }
                        controller.modalPresentationStyle = controller.navigationModel?.presentationType.style ?? .automatic

                        if let transitionStyle = controller.navigationModel?.presentationType.options.transistionStyle {
                            controller.modalTransitionStyle = transitionStyle.transistionStyle
                        }

                        if controller.navigationModel?.presentationType.options.preventDismissal == true {
                            controller.isModalInPresentation = true
                        }

                        if let type = controller.navigationModel?.presentationType, case let Model.PresentationType.detents(model, _) = type, let sheet = controller.sheetPresentationController {
                            sheet.prefersGrabberVisible = model.prefersGrabberVisible
                            if let preferredCornerRadius = model.preferredCornerRadius {
                                sheet.preferredCornerRadius = preferredCornerRadius
                            }
                            sheet.detents = Array(Set(model.detents.map { $0.detent }))
                            sheet.prefersEdgeAttachedInCompactHeight = true

                            if let selectedDetent = model.selected {
                                sheet.selectedDetentIdentifier = selectedDetent.detent.identifier
                            }

                            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
                            sheet.prefersScrollingExpandsWhenScrolledToEdge = model.prefersScrollingExpandsWhenScrolledToEdge
                            if let largestUndimmedDetentIdentifier = model.largestUndimmedDetentIdentifier?.detent.identifier {
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

            // swiftlint:enable cyclomatic_complexity function_body_length

            // MARK: NavPath methods

            @MainActor static func view(for navigationPath: Path, in navigationModel: Model, andInRoutes routes: [RouterView.Config]) -> UIRouteViewController? {
                guard
                    let (route, urlMatchResult) = Self.route(for: navigationPath, in: routes),
                    let route = route
                else {
                    return nil
                }

                let vc = viewController(of: route, with: urlMatchResult, for: navigationPath, in: navigationModel)

                if let vc {
                    return vc
                } else if let defaultRoute = Self.defaultRoute(in: routes), let defaultVc = viewController(of: defaultRoute, with: urlMatchResult, for: navigationPath, in: navigationModel) {
                    return defaultVc
                } else {
                    return RouteViewController(rootView: EmptyView())
                }
            }

            @MainActor public static func route(for navigationPath: Path, in routes: [RouterView.Config]) -> (RouterView.Config?, URLMatchResult?)? {
                let patterns = routes.flatMap { $0.routes.map { $0.pattern } }

                guard
                    let path = navigationPath.path,
                    let urlMatchResult = URLMatcher().match(path, from: patterns),
                    let route = routes.filter({ $0.routes.first { $0.pattern == urlMatchResult.pattern } != nil }).first // swiftlint:disable:this contains_over_first_not_nil first_where
                else {
                    // provide first
                    return (Self.defaultRoute(in: routes), nil)
                }

                guard route.validate(urlMatchResult) else {
                    return nil
                }
                return (route, urlMatchResult)
            }

            private static func defaultRoute(in routes: [RouterView.Config]) -> RouterView.Config? {
                routes.first { $0.defaultRoute }
            }

            private static func viewController(
                of route: RouterView.Config,
                with matchResult: URLMatchResult?,
                for navigationPath: Path,
                in navigationModel: Model
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
        // swiftlint:enable opening_brace
    }

    extension SwiftRouter.RouterView {
        func presentAlert(with model: SwiftRouter.AlertModel, in viewController: UIViewController) {
            let alert = UIAlertController(title: model.title, message: model.message, preferredStyle: model.type)

            for button in model.buttons ?? [.init(label: "OK")] {
                alert.addAction(UIAlertAction(title: button.label, style: button.type) { _ in
                    dispatch(SwiftRouter.Action.dismissedAlert(with: model))
                    button.action?()
                })
            }

            viewController.present(alert, animated: true)
        }
    }

    // MARK: Nested models

    public extension SwiftRouter.RouterView {
        struct Config: Sendable {
            public init(
                name: String? = nil,
                routes: [SwiftRouter.Route],
                render: (@MainActor (SwiftRouter.RouteViewModel) -> SwiftRouter.UIRouteViewController?)? = nil,
                defaultRoute: Bool = false
            ) {
                self.name = name
                self.routes = routes
                self.render = render
                self.defaultRoute = defaultRoute
            }

            public let name: String?
            public let routes: [SwiftRouter.Route]
            public let render: (@MainActor (SwiftRouter.RouteViewModel) -> SwiftRouter.UIRouteViewController?)?
            public let defaultRoute: Bool

            func validate(_ result: URLMatchResult) -> Bool {
                guard
                    let path = routes.first(where: { $0.pattern == result.pattern })
                else {
                    return false
                }

                return path.validate(result: result, forAccessLevel: .private)
            }
        }
    }

    public extension SwiftRouter.RouterView {
        struct NavigationControllerRoute {
            public init(paths: [SwiftRouter.Route], render: @escaping (SwiftRouter.Model, [String: URLPathMatchValue]?) -> SwiftRouter.Controller) {
                self.paths = paths
                self.render = render
            }

            public let paths: [SwiftRouter.Route]
            public let render: (
                SwiftRouter.Model,
                [String: URLPathMatchValue]?
            ) -> SwiftRouter.Controller
        }
    }

    extension UIApplication {
        func getAllUIWindows() -> [UIWindow] {
            let allWindows = connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            return allWindows
        }

        private var keyWindow: UIWindow? {
            UIApplication.shared.windowScene?.windows.first(where: \.isKeyWindow)
        }

        private var windowScene: UIWindowScene? {
            UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive && $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }
        }
    }

#endif
