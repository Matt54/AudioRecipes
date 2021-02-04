import SwiftUI

@main
struct AudioRecipesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(Conductor.shared)
        }
    }
}
