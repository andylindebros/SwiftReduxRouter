import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#endif
#if canImport(UIKit)
    public protocol TabControllerProvider: UIViewController {
        var onTabAlreadySelected: ((NavPath) -> Void)? { get set }

        var tabBar: UITabBar { get }

        var selectedIndex: Int { get set }

        var viewControllers: [UIViewController]? { get }
        func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool)
    }

    @available(iOS 13, *)
    public class TabController: UITabBarController, TabControllerProvider, UITabBarControllerDelegate {
        override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            super.dismiss(animated: flag, completion: completion)
        }

        override public func viewDidLoad() {
            super.viewDidLoad()
            delegate = self
        }

        public var onTabAlreadySelected: ((NavPath) -> Void)?
        public func tabBarController(_ tabBarController: UITabBarController, shouldSelect controller: UIViewController) -> Bool {
            if
                let selected = (tabBarController.selectedViewController as? NavigationController)?.navigationModel,
                let shouldSelectNavigationModel = (controller as? NavigationController)?.navigationModel,
                selected.id == shouldSelectNavigationModel.id
            {
                onTabAlreadySelected?(selected.selectedPath)
            }
            return true
        }
    }

    @available(iOS 13, *)
    open class NavigationController: UINavigationController, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var navigationModel: NavigationModel?
        var willShow: ((_ navigationModel: NavigationModel, _ NavPath: NavPath) -> Void)?
        var onDismiss: ((_ navigationModel: NavigationModel) -> Void)?
        var selectedDetentDidChange: ((String, NavigationModel) -> Void)?
        var isDismissing: Bool = false
        @discardableResult func setModel(to value: NavigationModel) -> Self {
            navigationModel = value
            return self
        }

        override open func viewDidLoad() {
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

        public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if let willShow = willShow, let vc = viewController as? UIRouteViewController, let navigationModel = vc.viewModel?.navigationModel, let navPath = vc.viewModel?.path {
                navigationController.setNavigationBarHidden(
                    vc.hideNavigationBar,
                    animated: animated
                )

                vc.navigationItem.backButtonDisplayMode = .minimal
                vc.navigationItem.largeTitleDisplayMode = .never
                vc.extendedLayoutIncludesOpaqueBars = true

                if let coordinator = viewController.transitionCoordinator, coordinator.isInteractive {
                    coordinator.notifyWhenInteractionChanges { context in
                        if !context.isCancelled {
                            willShow(navigationModel, navPath)
                        }
                    }
                } else {
                    willShow(navigationModel, navPath)
                }
            }
        }
    }

    extension NavigationController: UISheetPresentationControllerDelegate {
        public func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
            guard let navigationModel = navigationModel, let identifier = sheetPresentationController.selectedDetentIdentifier else { return }
            DispatchQueue.main.async { [weak self] in
                self?.selectedDetentDidChange?(identifier.rawValue, navigationModel)
            }
        }
    }

    @available(iOS 13, *)
    @MainActor
    public protocol UIRouteViewController: UIViewController {
        var hideNavigationBar: Bool { get }
        var viewModel: RouteViewModel? { get set }
    }

    public final class RouteViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
        public init(
            rootView: Content,
            viewModel: RouteViewModel? = nil,
            hideNavigationBar: Bool = false
        ) {
            self.viewModel = viewModel
            self.hideNavigationBar = hideNavigationBar
            super.init(rootView: rootView)
        }

        @available(*, unavailable)
        @MainActor dynamic required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public var viewModel: RouteViewModel?
        public let hideNavigationBar: Bool

        override public func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
        }
    }
#endif

// See this discussion regarding backswipe https://stackoverflow.com/questions/59921239/hide-navigation-bar-without-losing-swipe-back-gesture-in-swiftui
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
