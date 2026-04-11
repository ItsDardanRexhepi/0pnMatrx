import SwiftUI

/// The Discover tab — browse everything the platform can do.
///
/// Fetches the component registry from `GET /extensions/registry` on appear,
/// displays a 2-column grid of service cards with search filtering,
/// and lets users deep-link to Trinity with a pre-filled message.
struct DiscoverView: View {

    let baseURL: URL
    let onTryWithTrinity: (String) -> Void

    @State private var registry = ComponentRegistry.shared
    @State private var gate = FeatureGate.shared
    @State private var searchText = ""
    @State private var isRefreshing = false

    // Featured capabilities rotating strip
    private let featured: [(icon: String, title: String, subtitle: String)] = [
        ("doc.text.magnifyingglass", "Smart Contracts", "Convert any agreement to a self-executing contract"),
        ("dollarsign.arrow.circlepath", "DeFi Loans", "Borrow against crypto with no credit check"),
        ("paintpalette", "NFT Studio", "Mint, manage, and sell digital assets"),
    ]

    @State private var featuredIndex = 0
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Featured strip
                    featuredStrip
                        .padding(.bottom, 20)

                    // Search
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // Component grid
                    if filteredComponents.isEmpty && registry.isLoaded {
                        emptySearch
                    } else {
                        componentGrid
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(hex: "#0a0a0a"))
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await refreshRegistry()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if !registry.isLoaded {
                await registry.load()
            }
        }
        .onReceive(timer) { _ in
            withAnimation {
                featuredIndex = (featuredIndex + 1) % featured.count
            }
        }
    }

    // MARK: - Computed

    private var filteredComponents: [ComponentEntry] {
        let comps = registry.components.filter { $0.available }
        guard !searchText.isEmpty else { return comps }
        let query = searchText.lowercased()
        return comps.filter {
            $0.name.lowercased().contains(query)
            || $0.description.lowercased().contains(query)
            || $0.category.lowercased().contains(query)
        }
    }

    // MARK: - Featured strip

    private var featuredStrip: some View {
        TabView(selection: $featuredIndex) {
            ForEach(Array(featured.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "#00ff41"))
                        .frame(width: 52, height: 52)
                        .background(Color(hex: "#00ff41").opacity(0.1))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(item.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color(hex: "#0e0e0e"))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 120)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search services...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 15))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "#1e1e1e"))
        .cornerRadius(12)
    }

    // MARK: - Grid

    private var componentGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredComponents) { component in
                componentCard(component)
            }
        }
    }

    private func componentCard(_ component: ComponentEntry) -> some View {
        let isLocked = component.minimumTier > gate.currentTier

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: component.sfSymbol)
                    .font(.system(size: 20))
                    .foregroundColor(isLocked ? .secondary : Color(hex: "#00ff41"))
                Spacer()
                if isLocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text(component.minimumTier.displayName)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#222222"))
                    .cornerRadius(6)
                }
            }

            Text(component.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isLocked ? .secondary : .white)
                .lineLimit(1)

            Text(component.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                let message = "I want to use \(component.name): \(component.gatewayActions.first ?? component.id)"
                onTryWithTrinity(message)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 10))
                    Text("Try with Trinity")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(isLocked ? .secondary : Color(hex: "#00ff41"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    isLocked
                    ? Color(hex: "#1a1a1a")
                    : Color(hex: "#00ff41").opacity(0.1)
                )
                .cornerRadius(8)
            }
            .disabled(isLocked)
        }
        .padding(14)
        .background(Color(hex: "#0e0e0e"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
        )
    }

    // MARK: - Empty search

    private var emptySearch: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No services found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 60)
    }

    // MARK: - Refresh

    private func refreshRegistry() async {
        isRefreshing = true
        await registry.load()
        isRefreshing = false
    }
}

#if DEBUG
struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(
            baseURL: URL(string: "http://localhost:18790")!,
            onTryWithTrinity: { _ in }
        )
    }
}
#endif
