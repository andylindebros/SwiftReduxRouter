import SwiftReduxRouter
import SwiftUI

struct StandAloneView: View {
    var router = Router(
        routes: [
            RouterView.Route(
                route: NavigationRoute("root"),
                renderView: { _, _, router in
                    AnyView(
                        Button(action: {
                            router?.push(
                                path: NavigationPath("root"),
                                target: "root"
                            )
                        }) {
                            Text("Click me")
                        }
                    )
                }
            ),
        ]
    )

    var body: some View {
        self.router
    }
}
