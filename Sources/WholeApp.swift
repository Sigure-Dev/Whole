import SwiftUI

@main
struct WholeApp: App {
    @ObservedObject private var settings = Settings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.colorScheme)
        }
    }
}
