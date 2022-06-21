import Foundation
import SwiftUI

#if canImport(UIKit)

import UIKit


@available(iOS 13, *)
public class TabController: UITabBarController {
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}

@available(iOS 13, *)
public class NavigationController: UINavigationController, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var session: NavigationSession?
    var willShow: ((_ session: NavigationSession, _ navigationPath: NavigationPath) -> Void)?
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
        if let willShow = self.willShow, let vc = viewController as? UIRouteViewController, let session = vc.session, let navPath = vc.navigationPath {
            willShow(session, navPath)
        }
    }
}

@available(iOS 13, *)
public protocol UIRouteViewController: UIViewController {
    var session: NavigationSession? { get set }
    var navigationPath: NavigationPath? { get set }
}

@available(iOS 13, *)
open class RouteViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
    public var session: NavigationSession?
    public var navigationPath: NavigationPath?
}

#endif
