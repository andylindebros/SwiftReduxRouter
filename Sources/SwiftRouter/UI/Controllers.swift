import Foundation
import SwiftUI
#if os(iOS)
    import UIKit

    public extension Navigation {
        protocol Window {}
        protocol TabControllerProvider: UIViewController {
            var onTabAlreadySelected: ((Path) -> Void)? { get set }

            var tabBar: UITabBar { get }

            var selectedIndex: Int { get set }

            var viewControllers: [UIViewController]? { get }
            func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool)

            func showTip(withID: String, withNavigationModel: Navigation.Model)
        }
    }

    public extension Navigation {
        class TabController: UITabBarController, TabControllerProvider, UITabBarControllerDelegate {
            override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
                super.dismiss(animated: flag, completion: completion)
            }

            override public func viewDidLoad() {
                super.viewDidLoad()
                delegate = self
            }

            public var onTabAlreadySelected: ((Path) -> Void)?
            public func tabBarController(_ tabBarController: UITabBarController, shouldSelect controller: UIViewController) -> Bool {
                if
                    let selected = (tabBarController.selectedViewController as? Controller)?.navigationModel,
                    let shouldSelectNavigationModel = (controller as? Controller)?.navigationModel,
                    selected.id == shouldSelectNavigationModel.id
                {
                    onTabAlreadySelected?(selected.selectedPath)
                }
                return true
            }

            public func showTip(withID _: String, withNavigationModel _: Navigation.Model) {
                assertionFailure("💥 ❌ Tip support not implemented")
            }
        }
    }

    extension Navigation {
        open class Controller: UINavigationController, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
            var navigationModel: Model?
            var willShow: ((_ navigationModel: Model, _ path: Path) -> Void)?
            var onDismiss: ((_ navigationModel: Model) -> Void)?
            var selectedDetentDidChange: ((String, Model) -> Void)?
            var isDismissing: Bool = false
            @discardableResult func setModel(to value: Model) -> Self {
                navigationModel = value
                return self
            }

            override open func viewDidLoad() {
                super.viewDidLoad()
                delegate = self
                presentationController?.delegate = self
            }

            override public func viewWillDisappear(_ animated: Bool) {
                super.viewDidDisappear(animated)
                if let coordinator = transitionCoordinator, coordinator.isInteractive {
                    // ViewController is being dismissed interactivly
                } else if let navigationModel = navigationModel {
                    onDismiss?(navigationModel)
                }
            }

            public func presentationControllerDidDismiss(_: UIPresentationController) {
                if let navigationModel = navigationModel {
                    onDismiss?(navigationModel)
                }
            }

            public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
                if let willShow = willShow, let vc = viewController as? UIRouteViewController, let navigationModel = navigationModel, let navPath = vc.viewModel?.path {
                    navigationController.setNavigationBarHidden(
                        vc.viewModel?.path.navBarOptions?.hideNavigationBar ?? vc.hideNavigationBar ?? false,
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
                        if navigationModel.presentedPaths.last?.id != navPath.id {
                            if vc.viewModel?.hasBeenShown == true {
                                willShow(navigationModel, navPath)
                            }
                        } else {
                            willShow(navigationModel, navPath)
                        }
                    }
                }
            }
        }
    }

    extension Navigation.Controller: UISheetPresentationControllerDelegate {
        public func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
            guard let navigationModel = navigationModel, let identifier = sheetPresentationController.selectedDetentIdentifier else { return }
            DispatchQueue.main.async { [weak self] in
                self?.selectedDetentDidChange?(identifier.rawValue, navigationModel)
            }
        }
    }

    public extension Navigation {
        @MainActor protocol UIRouteViewController: UIViewController {
            var hideNavigationBar: Bool? { get }
            var viewModel: Navigation.RouteViewModel? { get set }
        }
    }

    public extension Navigation {
        final class RouteViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
            public init(
                rootView: Content,
                viewModel: Navigation.RouteViewModel? = nil,
                hideNavigationBar: Bool? = nil
            ) {
                self.viewModel = viewModel
                self.hideNavigationBar = hideNavigationBar
                super.init(rootView: rootView)
            }

            @available(*, unavailable)
            @MainActor dynamic required init?(coder _: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            public var viewModel: Navigation.RouteViewModel?
            public let hideNavigationBar: Bool?
        }
    }

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
#endif
