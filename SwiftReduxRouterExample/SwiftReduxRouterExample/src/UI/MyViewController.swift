import SwiftReduxRouter
import SwiftUI
import UIKit

class MyCustomNavigationController: NavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}

class HiddenNavigationBarViewController<Content: View>: UIHostingController<Content>, UIRouteViewController {
    var navigationModel: SwiftReduxRouter.NavigationModel?
    var navigationPath: NavPath?

    override init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .blue

        title = "Awesome"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}
