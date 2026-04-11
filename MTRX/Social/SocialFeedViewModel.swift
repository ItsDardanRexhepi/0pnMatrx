import Foundation
import Combine
import SwiftUI

/// View model for the social activity feed tab.
///
/// Manages feed loading, pagination, filtering, trending data,
/// stats, and live SSE updates. Designed for use with
/// ``SocialFeedView``.
@MainActor
final class SocialFeedViewModel: ObservableObject {

    // MARK: - Published state

    @Published var events: [FeedEvent] = []
    @Published var trending: [TrendingAction] = []
    @Published var stats: FeedStats?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var selectedCategory: String? = nil
    @Published var isConnected = false

    // MARK: - Configuration

    private let baseURL: URL
    private let pageSize = 50
    private var currentOffset = 0
    private var knownIds = Set<String>()
    private let sseClient: SSEClient
    private var cancellables = Set<AnyCancellable>()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Available filter categories.
    static let categories = [
        "All", "DeFi", "NFT", "Governance",
        "Contracts", "Identity", "Finance",
    ]

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.sseClient = SSEClient(baseURL: baseURL)

        // Subscribe to SSE events
        sseClient.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLiveEvent(event)
            }
            .store(in: &cancellables)

        sseClient.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
    }

    // MARK: - Public API

    func load() async {
        isLoading = true
        currentOffset = 0
        knownIds.removeAll()

        async let feedTask: () = loadFeed(append: false)
        async let trendingTask: () = loadTrending()
        async let statsTask: () = loadStats()

        await feedTask
        await trendingTask
        await statsTask

        isLoading = false
        sseClient.connect()
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        currentOffset += pageSize
        await loadFeed(append: true)
        isLoadingMore = false
    }

    func refresh() async {
        await load()
    }

    func selectCategory(_ category: String?) {
        selectedCategory = category == "All" ? nil : category
    }

    /// Events filtered by the currently selected category.
    var filteredEvents: [FeedEvent] {
        guard let cat = selectedCategory else { return events }
        return events.filter { ($0.category ?? "Other") == cat }
    }

    func disconnect() {
        sseClient.disconnect()
    }

    // MARK: - Network

    private func loadFeed(append: Bool) async {
        var components = URLComponents(url: baseURL.appendingPathComponent("/social/feed"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "offset", value: "\(currentOffset)"),
        ]
        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(FeedResponse.self, from: data)
            let newEvents = response.events

            for event in newEvents {
                knownIds.insert(event.id)
            }

            if append {
                events.append(contentsOf: newEvents)
            } else {
                events = newEvents
            }
            hasMore = newEvents.count >= pageSize
        } catch {
            print("[SocialFeed] Feed load error: \(error)")
        }
    }

    private func loadTrending() async {
        let url = baseURL.appendingPathComponent("/social/trending")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(TrendingResponse.self, from: data)
            trending = response.trending
        } catch {
            print("[SocialFeed] Trending load error: \(error)")
        }
    }

    private func loadStats() async {
        let url = baseURL.appendingPathComponent("/social/stats")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(StatsResponse.self, from: data)
            stats = response.stats
        } catch {
            print("[SocialFeed] Stats load error: \(error)")
        }
    }

    // MARK: - Live updates

    private func handleLiveEvent(_ event: FeedEvent) {
        guard !knownIds.contains(event.id) else { return }
        knownIds.insert(event.id)

        withAnimation(.spring(response: 0.3)) {
            events.insert(event, at: 0)
        }

        // Cap local list to prevent unbounded growth
        if events.count > 500 {
            events = Array(events.prefix(500))
        }
    }
}

// MARK: - Response types

private struct FeedResponse: Decodable {
    let events: [FeedEvent]
    let count: Int
    let offset: Int
    let limit: Int
}

private struct TrendingResponse: Decodable {
    let trending: [TrendingAction]
    let windowHours: Int?

    enum CodingKeys: String, CodingKey {
        case trending
        case windowHours = "window_hours"
    }
}

struct TrendingAction: Identifiable, Decodable {
    var id: String { eventType }
    let eventType: String
    let label: String
    let count: Int
    let avgScore: Double
    let maxValueUsd: Double?
    let uniqueActors: Int

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case label, count
        case avgScore = "avg_score"
        case maxValueUsd = "max_value_usd"
        case uniqueActors = "unique_actors"
    }
}

struct FeedStats: Decodable {
    let totalEvents: Int
    let uniqueActors: Int
    let uniqueActionTypes: Int
    let eventsLast24h: Int
    let avgScore: Double
    let mostActiveActor: MostActiveActor?

    enum CodingKeys: String, CodingKey {
        case totalEvents = "total_events"
        case uniqueActors = "unique_actors"
        case uniqueActionTypes = "unique_action_types"
        case eventsLast24h = "events_last_24h"
        case avgScore = "avg_score"
        case mostActiveActor = "most_active_actor"
    }

    struct MostActiveActor: Decodable {
        let address: String
        let eventCount: Int

        enum CodingKeys: String, CodingKey {
            case address
            case eventCount = "event_count"
        }
    }
}

private struct StatsResponse: Decodable {
    let stats: FeedStats
}
