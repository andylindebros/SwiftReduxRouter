import SwiftReduxRouter
import UIKit

class MyViewController: UIViewController, UIRouteViewController {
    var session: NavigationSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .blue

        title = "Awesome"
    }
}
