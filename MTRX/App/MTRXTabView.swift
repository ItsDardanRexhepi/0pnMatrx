import SwiftUI

/// Root tab navigation for the MTRX iOS app.
///
/// Five tabs in locked order:
///   1. Discover  — browse platform capabilities
///   2. Build     — developer tools, marketplace, SDK
///   3. Home      — Trinity chat (default on launch)
///   4. Social    — live activity feed
///   5. Account   — wallet, subscription, settings
///
/// Home is always the default selected tab.
struct MTRXTabView: View {

    enum Tab: Int, CaseIterable {
        case discover = 0
        case build    = 1
        case home     = 2
        case social   = 3
        case account  = 4
    }

    @State private var selectedTab: Tab = .home

    /// Pre-filled message to send to Trinity when deep-linking from Discover.
    /// Set this before switching to .home and HomeView will pick it up.
    @State private var pendingTrinityMessage: String = ""

    /// Gateway base URL — shared across tabs that need it.
    private let baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:18790")!) {
        self.baseURL = baseURL

        // Tab bar appearance: pure black background, green/grey tint
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(
            red: 0x66 / 255.0,
            green: 0x66 / 255.0,
            blue: 0x66 / 255.0,
            alpha: 1.0
        )
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(
                red: 0x66 / 255.0,
                green: 0x66 / 255.0,
                blue: 0x66 / 255.0,
                alpha: 1.0
            )
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(
            red: 0x00 / 255.0,
            green: 0xFF / 255.0,
            blue: 0x41 / 255.0,
            alpha: 1.0
        )
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(
                red: 0x00 / 255.0,
                green: 0xFF / 255.0,
                blue: 0x41 / 255.0,
                alpha: 1.0
            )
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Discover ──────────────────────────────────
            DiscoverView(
                baseURL: baseURL,
                onTryWithTrinity: { message in
                    pendingTrinityMessage = message
                    selectedTab = .home
                }
            )
            .tabItem {
                Label("Discover", systemImage: "safari")
            }
            .tag(Tab.discover)

            // ── Tab 2: Build ─────────────────────────────────────
            BuildView(baseURL: baseURL)
                .tabItem {
                    Label("Build", systemImage: "hammer")
                }
                .tag(Tab.build)

            // ── Tab 3: Home (Trinity) ────────────────────────────
            HomeView(
                baseURL: baseURL,
                pendingMessage: $pendingTrinityMessage
            )
            .tabItem {
                Label("Home", systemImage: "message.fill")
            }
            .tag(Tab.home)

            // ── Tab 4: Social ────────────────────────────────────
            SocialFeedView(baseURL: baseURL)
                .tabItem {
                    Label("Social", systemImage: "globe")
                }
                .tag(Tab.social)

            // ── Tab 5: Account ───────────────────────────────────
            AccountView(baseURL: baseURL)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(Tab.account)
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
struct MTRXTabView_Previews: PreviewProvider {
    static var previews: some View {
        MTRXTabView()
    }
}
#endif
