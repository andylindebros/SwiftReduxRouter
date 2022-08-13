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
    var navigationModel: NavigationModel?
    var willShow: ((_ navigationModel: NavigationModel, _ navigationPath: NavigationPath) -> Void)?
    var onDismiss: ((_ navigationModel: NavigationModel) -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        presentationController?.delegate = self
    }

    public func presentationControllerDidDismiss(_: UIPresentationController) {
        // call whatever you want
        if let navigationModel = navigationModel {
            onDismiss?(navigationModel)
        }
    }

    public func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
        if let willShow = self.willShow, let vc = viewController as? UIRouteViewController, let navigationModel = vc.navigationModel, let navPath = vc.navigationPath {
            willShow(navigationModel, navPath)
        }
    }
}

@available(iOS 13, *)
public protocol UIRouteViewController: UIViewController {
    var navigationModel: NavigationModel? { get set }
    var navigationPath: NavigationPath? { get set }
}

public struct Wrapper<Content: View>: View {
    let hideNavigationBar: Bool
    @ViewBuilder let content: () -> Content

    public var body: some View {
        content().navigationBarHidden(hideNavigationBar)
    }
}

public final class RouteViewController<Content: View>: UIHostingController<Wrapper<Content>>, UIRouteViewController {
    public init(
        rootView: Content,
        navigationModel: NavigationModel? = nil,
        navigationPath: NavigationPath? = nil,
        hideNavigationBar: Bool = false,
        title: String? = nil
    ) {
        self.navigationModel = navigationModel
        self.navigationPath = navigationPath
        self.hideNavigationBar = hideNavigationBar
        super.init(rootView: Wrapper(hideNavigationBar: hideNavigationBar) { rootView })
        self.title = title
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var navigationModel: NavigationModel?
    public var navigationPath: NavigationPath?

    public var hideNavigationBar: Bool

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard hideNavigationBar else { return }
        navigationController?.setNavigationBarHidden(hideNavigationBar, animated: animated)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard hideNavigationBar else { return }
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
#endif
