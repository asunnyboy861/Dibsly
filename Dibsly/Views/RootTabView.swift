import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NearbyRootView()
                    .tabItem { Label("Nearby", systemImage: "map.fill") }
                    .tag(0)

                WantedView()
                    .tabItem { Label("Wanted", systemImage: "hand.raised.fill") }
                    .tag(1)

                PostItemView()
                    .tabItem { Label("Post", systemImage: "plus.circle.fill") }
                    .tag(2)

                MyHaulsView()
                    .tabItem { Label("Hauls", systemImage: "bag.fill") }
                    .tag(3)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                    .tag(4)
            }

            if !env.hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .task {
            env.bootstrap()
            if env.hasOnboarded {
                env.location.requestPermission()
            }
            await PurchaseManager.shared.refreshEntitlements()
        }
        .onChange(of: env.location.city) { _, city in
            env.updateCity(city)
        }
    }
}
