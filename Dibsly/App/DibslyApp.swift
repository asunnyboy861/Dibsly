import SwiftData
import SwiftUI

@main
struct DibslyApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
                .modelContainer(environment.container)
                .tint(DesignSystem.green)
        }
    }
}
