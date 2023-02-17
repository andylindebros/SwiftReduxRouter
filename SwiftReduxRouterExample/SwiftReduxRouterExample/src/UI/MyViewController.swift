import SwiftReduxRouter
import UIKit

@MainActor
class MyViewController: UIViewController, UIRouteViewController {
    var navigationModel: NavigationModel?
    var navigationPath: NavigationPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .blue

        title = "Awesome"
    }
}
