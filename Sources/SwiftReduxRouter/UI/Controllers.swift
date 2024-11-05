import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#endif
#if canImport(UIKit)
    @available(iOS 13, *)
    public class TabController: UITabBarController, UITabBarControllerDelegate {
        override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            super.dismiss(animated: flag, completion: completion)
        }

        override public func viewDidLoad() {
            super.viewDidLoad()
            delegate = self
        }

        public var onTabAlreadySelected: ((NavigationPath) -> Void)?
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
        var willShow: ((_ navigationModel: NavigationModel, _ navigationPath: NavigationPath) -> Void)?
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

        public func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
            if let willShow = willShow, let vc = viewController as? UIRouteViewController, let navigationModel = vc.navigationModel, let navPath = vc.navigationPath {
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
        var navigationModel: NavigationModel? { get set }
        var navigationPath: NavigationPath? { get set }
    }

    public final class RouteViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
        public init(
            rootView: Content,
            navigationModel: NavigationModel? = nil,
            navigationPath: NavigationPath? = nil
        ) {
            self.navigationModel = navigationModel
            self.navigationPath = navigationPath
            super.init(rootView: rootView)
        }

        @available(*, unavailable)
        @MainActor dynamic required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public var navigationModel: NavigationModel?
        public var navigationPath: NavigationPath?
    }
#endif
