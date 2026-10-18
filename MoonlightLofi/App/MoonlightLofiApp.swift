import SwiftData
import SwiftUI

@main
struct MoonlightLofiApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Palette.moon)
        }
        .modelContainer(MoonlightStore.container)
    }
}
