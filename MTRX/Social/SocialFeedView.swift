import SwiftUI

/// The main social activity feed tab in the MTRX iOS app.
///
/// Layout:
///   - Stats header strip
///   - Category filter pills
///   - Scrollable ranked event list with pull-to-refresh
///   - Trending sidebar (on iPad, inline on iPhone)
///   - SSE connection indicator
struct SocialFeedView: View {
    @StateObject private var viewModel: SocialFeedViewModel

    init(baseURL: URL) {
        _viewModel = StateObject(wrappedValue: SocialFeedViewModel(baseURL: baseURL))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Connection status
                    connectionBar

                    // Stats strip
                    if let stats = viewModel.stats {
                        statsStrip(stats)
                    }

                    // Category filters
                    categoryFilters
                        .padding(.vertical, 12)

                    // Feed list
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredEvents) { event in
                            FeedEventRow(event: event)
                        }

                        if viewModel.hasMore && !viewModel.isLoadingMore {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task { await viewModel.loadNextPage() }
                                }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(Color(hex: "#00ff41"))
                                .padding()
                        }
                    }
                    .padding(.horizontal, 16)

                    if viewModel.filteredEvents.isEmpty && !viewModel.isLoading {
                        emptyState
                    }
                }
            }
            .background(Color(hex: "#0a0a0a"))
            .navigationTitle("Live Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }

    // MARK: - Subviews

    private var connectionBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected
                      ? Color(hex: "#00ff41")
                      : Color.red)
                .frame(width: 7, height: 7)
                .shadow(color: viewModel.isConnected
                        ? Color(hex: "#00ff41").opacity(0.5)
                        : .clear,
                        radius: 4)
            Text(viewModel.isConnected ? "Live" : "Reconnecting...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func statsStrip(_ stats: FeedStats) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statPill(value: "\(stats.totalEvents)", label: "events")
                statPill(value: "\(stats.uniqueActors)", label: "actors")
                statPill(value: "\(stats.uniqueActionTypes)", label: "types")
                statPill(value: "\(stats.eventsLast24h)", label: "24h")
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#00ff41"))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(hex: "#0e0e0e"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
        )
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SocialFeedViewModel.categories, id: \.self) { cat in
                    let isSelected = (cat == "All" && viewModel.selectedCategory == nil)
                        || cat == viewModel.selectedCategory
                    Button {
                        viewModel.selectCategory(cat)
                    } label: {
                        Text(cat)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected
                                        ? Color(hex: "#00ff41").opacity(0.12)
                                        : Color(hex: "#0e0e0e"))
                            .foregroundColor(isSelected
                                             ? Color(hex: "#00ff41")
                                             : .secondary)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected
                                            ? Color(hex: "#00ff41").opacity(0.4)
                                            : Color(hex: "#1e1e1e"),
                                            lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("\u{1F4E1}")
                .font(.system(size: 40))
            Text("No activity yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Actions will appear here in real time.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 60)
    }
}

#if DEBUG
struct SocialFeedView_Previews: PreviewProvider {
    static var previews: some View {
        SocialFeedView(baseURL: URL(string: "http://localhost:18790")!)
    }
}
#endif
