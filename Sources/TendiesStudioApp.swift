import SwiftUI

@main
struct TendiesStudioApp: App {
    @StateObject private var workspace = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .preferredColorScheme(.dark)
        }
    }
}
