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
    private var setSelectedPath: (_ session: NavigationSession) -> Void

    /// onDismiss is invoked when the UIViewController will be dismissed
    private var onDismiss: (_ session: NavigationSession) -> Void

    private var standaloneRouter: Router?

    private var tintColor: UIColor?
    /// Public init
    public init(
        navigationState: NavigationState,
        routes: [Route],
        tintColor: UIColor? = nil,
        setSelectedPath: @escaping (_ session: NavigationSession) -> Void,
        onDismiss: @escaping (_ session: NavigationSession) -> Void,
        standaloneRouter: Router? = nil
    ) {
        self.navigationState = navigationState
        self.routes = routes
        self.setSelectedPath = setSelectedPath
        self.onDismiss = onDismiss
        self.standaloneRouter = standaloneRouter
        self.tintColor = tintColor
    }

    public func makeUIViewController(context _: Context) -> UIViewController {
        return recreateViewControllerBasedOnState()
    }

//    public func makeCoordinator() -> () {
//        return RouterCoordinator(navigtionState: navigationState)
//    }

    /**
     Updates the SwiftUI View when the state changes
     */

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

    func recreateViewControllerBasedOnState(rootController: UIViewController? = nil) -> UIViewController {
        // Appear as a tabbar. Initial state has more than one session
        if navigationState.sessions.count > 1 {
            let tc = asTabBarController(rootController)
            if let tintColor = tintColor {
                tc.tabBar.tintColor = tintColor
            }
            var ncs = [NavigationController]()
            for session in navigationState.sessions.filter({ $0.tab != nil }) {
                let nc: NavigationController = tc.viewControllers?.compactMap { $0 as? NavigationController }.first(where: { $0.session?.id == session.id }) ?? NavigationController()
                recreateSession(nc: nc, session: session)

//                let nc: NavigationController
//                if let vc = getViewByPath(session, navigationPath: ) {
//                    nc = NavigationController(rootViewController: vc)
//                } else {
//                    nc = NavigationController()
//                }
//                nc.session = session
//                nc.willShow = setSelectedPath
//                nc.onDismiss = onDismiss

                if let tab = session.tab {
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
                }
                ncs.append(nc)
            }
            tc.viewControllers = ncs

            return tc

            // Appear as a NavigationController. Initial state has only one session
        } else {
            var tnc = asNavigationController(rootController)
            guard let session = navigationState.sessions.first else { return tnc }
            if let vc = getViewByPath(session, navigationPath: session.nextPath) {
                tnc = NavigationController(rootViewController: vc)
            } else {
                tnc = NavigationController()
            }
            tnc.session = session
            tnc.willShow = setSelectedPath
            tnc.onDismiss = onDismiss

            return tnc
        }
    }

    func recreateSession(nc: NavigationController, session: NavigationSession) {
        nc.session = session
        nc.willShow = setSelectedPath
        nc.onDismiss = onDismiss
        // session.presentedPaths.compactMap(T##transform: (NavigationPath) throws -> ElementOfResult?##(NavigationPath) throws -> ElementOfResult?)
        let vcs = session.presentedPaths.compactMap{ path in
           nc.viewControllers.compactMap{ $0 as? UIRouteViewController }.first(where: { $0.navigationPath?.id == path.id }) ?? getViewByPath(session, navigationPath: path)
        }
        nc.viewControllers = vcs
    }

    public func updateUIViewController(_ vc: UIViewController, context _: Context) {
        
        //_ = recreateViewControllerBasedOnState(rootController: vc)
        // context.coordinator.update(navigationState: navigationState)

//        guard let session = navigationState.sessions.first(where: { $0.id == navigationState.selectedSessionId }) else {
//            return
//        }
//        if session.nextPath.id != session.selectedPath.id {
//            if let selectedIndex = navigationState.sessions.filter({ $0.tab != nil || $0.id == navigationState.sessions.first?.id }).firstIndex(where: { $0.id == session.id }) {
//                var ncRaw: NavigationController?
//                if let tc = tc as? UITabBarController {
//                    tc.selectedIndex = selectedIndex
//
//                    if let tnc = tc.selectedViewController as? NavigationController {
//                        ncRaw = tnc
//                    }
//
//                } else if let nnc = tc as? NavigationController {
//                    ncRaw = nnc
//                }
//
//                guard let nc = ncRaw else {
//                    return
//                }
//                nc.session = session
//
//                switch session.nextPath.path {
//                case NavigationGoBackIdentifier.back.rawValue:
//                    nc.popViewController(animated: true)
//                    return
//                case NavigationGoBackIdentifier.root.rawValue:
//                    nc.popToRootViewController(animated: true)
//                    return
//                default:
//                    if let vc = getViewByPath(session, navigationPath: session.nextPath) {
//                        nc.pushViewController(vc, animated: true)
//                        return
//                    }
//                }
//            }
//
//            guard let keyWindow = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
//                return
//            }
//
//            var topController = keyWindow.rootViewController
//            while topController?.presentedViewController != nil {
//                topController = topController?.presentedViewController
//
//                if let nc = topController as? NavigationController, let ncSession = nc.session, ncSession.id == session.id {
//                    nc.session = session
//                    switch session.nextPath.path {
//                    case NavigationGoBackIdentifier.back.rawValue:
//                        nc.popViewController(animated: true)
//                        return
//                    case NavigationGoBackIdentifier.root.rawValue:
//                        nc.popToRootViewController(animated: true)
//                        return
//                    case Self.dismissActionIdentifier:
//                        nc.dismiss(animated: true, completion: {
//                            nc.onDismiss?(session)
//                        })
//                        return
//                    default:
//                        if let vc = getViewByPath(session) {
//                            nc.pushViewController(vc, animated: true)
//                            return
//                        }
//                    }
//                }
//            }
//
//            guard let vc = getViewByPath(session, navigationPath: session.nextPath) else { return }
//
//            let nc = NavigationController(rootViewController: vc)
//            nc.session = session
//            nc.willShow = setSelectedPath
//            nc.onDismiss = onDismiss
//
//            topController?.present(nc, animated: true)
//            setSelectedPath(session)
//        }
    }

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
            route.onWillAppear?(session.nextPath, match.values)
            return viewController
        }

        return nil
    }
}

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

public class TabController: UITabBarController {
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}

public class NavigationController: UINavigationController, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var session: NavigationSession?
    var willShow: ((_ session: NavigationSession) -> Void)?
    var onDismiss: ((_ session: NavigationSession) -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        presentationController?.delegate = self
    }

    public func presentationControllerDidDismiss(_: UIPresentationController) {
        // call whatever you want
        if let session = session {
            onDismiss?(session)
        }
    }

    public func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
        if let vc = viewController as? UIRouteViewController, let session = vc.session {
            willShow?(session)
        }
    }
}

public protocol UIRouteViewController: UIViewController {
    var session: NavigationSession? { get set }
    var navigationPath: NavigationPath? { get set }
}

open class RouteViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
    public var session: NavigationSession?
    public var navigationPath: NavigationPath?
}
