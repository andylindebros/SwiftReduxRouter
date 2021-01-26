import SwiftReduxRouter
import SwiftUI

struct ContentView: View {
    
    var store: AppStore
    
    var body: some View {
        RouterView(
            navigationState: store.store.state.navigation,
            routes: AppRoutes.allCases.map { $0.route },
            tintColor: .red,
            setSelectedPath: { session in
                store.store.dispatch(NavigationActions.SetSelectedPath(session: session))
            },
            onDismiss: { session in
                store.store.dispatch(NavigationActions.SessionDismissed(session: session))
            }
        )
        // Uncomment this and comment out the above to test the stand alone view
        // StandAloneView()
        .edgesIgnoringSafeArea(.all)
        .background(Color.red)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: AppStore())
    }
}
