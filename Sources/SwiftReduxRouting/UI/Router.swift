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
    private var tc: UIViewController

    /// Available routes
    private var routes: [Route]

    /// setSelectedPath is invoked by the UIViewController when it is in screen
    private var setSelectedPath: (_ session: NavigationSession) -> Void

    /// onDismiss is invoked when the UIViewController will be dismissed
    private var onDismiss: (_ session: NavigationSession) -> Void

    private var standaloneRouter: Router?

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

        tc = NavigationController()

        // Appear as a tabbar. Initial state has more than one session
        if navigationState.sessions.count > 1 {
            let tc = TabController()
            if let tintColor = tintColor {
                tc.tabBar.tintColor = tintColor
            }
            var ncs = [NavigationController]()
            for session in navigationState.sessions.filter({ $0.tab != nil }) {
                let nc: NavigationController
                if let vc = getViewByPath(session) {
                    nc = NavigationController(rootViewController: vc)
                } else {
                    nc = NavigationController()
                }
                nc.session = session
                nc.willShow = setSelectedPath
                nc.onDismiss = onDismiss

                if let tab = session.tab {
                    nc.tabBarItem = UITabBarItem(
                        title: tab.name,
                        image: UIImage(named: tab.icon),
                        selectedImage: UIImage(
                            named: tab.selectedIcon ?? tab.icon
                        )
                    )
                }
                ncs.append(nc)
            }
            tc.viewControllers = ncs

            self.tc = tc

            // Appear as a NavigationController. Initial state has only one session
        } else {
            var tc: NavigationController!
            guard let session = navigationState.sessions.first else { return }
            if let vc = getViewByPath(session) {
                tc = NavigationController(rootViewController: vc)
            } else {
                tc = NavigationController()
            }
            tc.session = session
            tc.willShow = setSelectedPath
            tc.onDismiss = onDismiss

            self.tc = tc
        }
    }

    public func makeUIViewController(context _: Context) -> UIViewController {
        return tc
    }

    /**
     Updates the SwiftUI View when the state changes
     */
    public func updateUIViewController(_ tc: UIViewController, context _: Context) {
        guard let session = navigationState.sessions.first(where: { $0.id == navigationState.selectedSessionId }) else {
            return
        }

        // UITabBar
        if session.nextPath.id != session.selectedPath.id {
            if let selectedIndex = navigationState.sessions.filter({ $0.tab != nil || $0.id == navigationState.sessions.first?.id }).firstIndex(where: { $0.id == session.id }) {
                
                var nc: NavigationController!
                if let tc = tc as? UITabBarController, let tnc = tc.selectedViewController as? NavigationController {
                    tc.selectedIndex = selectedIndex
                    nc = tnc
                }else if let nnc = tc as? NavigationController {
                    nc = nnc
                }
                
                nc.session = session

                switch session.nextPath.path {
                case NavigationGoBackIdentifier.back.rawValue:
                    nc.popViewController(animated: true)
                    return
                case NavigationGoBackIdentifier.root.rawValue:
                    nc.popToRootViewController(animated: true)
                    return
                default:
                    if let vc = getViewByPath(session) {
                        nc.pushViewController(vc, animated: true)
                        return
                    }
                }
            }

            guard let keyWindow = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
                return
            }

            var topController = keyWindow.rootViewController
            while topController?.presentedViewController != nil {
                topController = topController?.presentedViewController

                if let nc = topController as? NavigationController, let ncSession = nc.session, ncSession.id == session.id {
                    nc.session = session
                    switch session.nextPath.path {
                    case NavigationGoBackIdentifier.back.rawValue:
                        nc.popViewController(animated: true)
                        return
                    case NavigationGoBackIdentifier.root.rawValue:
                        nc.popToRootViewController(animated: true)
                        return
                    case Self.dismissActionIdentifier:
                        nc.dismiss(animated: true, completion: {
                            nc.onDismiss?(session)
                        })
                        return
                    default:
                        if let vc = getViewByPath(session) {
                            nc.pushViewController(vc, animated: true)
                            return
                        }
                    }
                }
            }

            guard let vc = getViewByPath(session) else { return }

            let nc = NavigationController(rootViewController: vc)
            nc.session = session
            nc.willShow = setSelectedPath
            nc.onDismiss = onDismiss

            topController?.present(nc, animated: true)
            setSelectedPath(session)
        }
    }

    public func getViewByPath(_ session: NavigationSession) -> RouteViewController<AnyView>? {
        let patterns = routes.map { $0.path }

        if
            let match = URLMatcher().match(session.nextPath.path, from: patterns),
            let route = routes.first(where: { $0.path == match.pattern }) {
            let vc: RouteViewController<AnyView>!
            if let renderController = route.renderController {
                vc = renderController(session.nextPath, match.values, standaloneRouter)
            } else if let render = route.render {
                var view = render(session.nextPath, match.values, standaloneRouter)
                view = AnyView(view.edgesIgnoringSafeArea(.all))
                vc = RouteViewController(rootView: view)
            } else {
                vc = RouteViewController(rootView: AnyView(EmptyView()))
            }
            vc.session = session
            vc.configureBeforePushed()

            route.onWillAppear?(session.nextPath, match.values)
            return vc
        }

        return nil
    }
}

public extension RouterView {
    struct Route {
        public var path: String
        public var onWillAppear: ((_ path: NavigationPath, _ values: [String: Any]) -> Void)?
        public var render: ((_ path: NavigationPath, _ values: [String: Any], _ router: Router?) -> AnyView)?
        public var renderController: ((_ path: NavigationPath, _ values: [String: Any], _ router: Router?) -> RouteViewController<AnyView>)?

        public init(
            path: String,
            onWillAppear: ((NavigationPath, [String: Any]) -> Void)? = nil,
            render: ((NavigationPath, [String: Any], _ router: Router?) -> AnyView)? = nil,
            renderController: ((_ path: NavigationPath, _ values: [String: Any], _ router: Router?) -> RouteViewController<AnyView>)? = nil
        )
        {
            self.path = path
            self.onWillAppear = onWillAppear
            self.render = render
            self.renderController = renderController
        }
    }
}

public class TabController: UITabBarController {
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
    }
}

public class NavigationController: UINavigationController, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var session: NavigationSession?
    var willShow: ((_ session: NavigationSession) -> Void)?
    var onDismiss: ((_ session: NavigationSession) -> Void)?

    public override func viewDidLoad() {
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
        if let vc = viewController as? RouteViewController<AnyView>, let session = vc.session {
            willShow?(session)
        }
    }
}

open class RouteViewController<Content: View>: UIHostingController<Content> {
    public var session: NavigationSession?
    open func configureBeforePushed() {}
}
