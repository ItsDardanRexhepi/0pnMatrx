// MTRX/Extensions/ComponentRegistry.swift
// Copy this file to the MTRX iOS app's Extensions group.

import SwiftUI

/// Mirrors the gateway's extensions/registry.json structure.
struct ComponentManifest: Codable {
    let version: String
    let platform: String?
    let components: [ComponentEntry]
}

/// A single component from the registry.
struct ComponentEntry: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let minTier: String
    let limits: [String: [String: AnyCodableValue]]
    let gatewayActions: [String]
    let icon: String
    let available: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, icon, available, limits
        case minTier = "min_tier"
        case gatewayActions = "gateway_actions"
    }

    var minimumTier: SubscriptionTier {
        SubscriptionTier(rawValue: minTier) ?? .free
    }

    var sfSymbol: String {
        icon
    }
}

/// Type-erased Codable value for limit entries (int, bool, or float).
enum AnyCodableValue: Codable {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(AnyCodableValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

/// Fetches and caches the component registry from the gateway.
@Observable
final class ComponentRegistry {
    static let shared = ComponentRegistry()

    private(set) var components: [ComponentEntry] = []
    private(set) var isLoaded = false

    private let gatewayURL: String
    private let cacheKey = "cached_component_registry"

    init(gatewayURL: String = "http://localhost:18790") {
        self.gatewayURL = gatewayURL
        loadFromCache()
    }

    /// Fetch the registry from the gateway.
    func load() async {
        guard let url = URL(string: "\(gatewayURL)/extensions/registry") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(ComponentManifest.self, from: data)
            components = manifest.components
            isLoaded = true

            // Cache for offline use
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to load component registry: \(error)")
        }
    }

    /// Filter components available for a given tier.
    func availableComponents(for tier: SubscriptionTier) -> [ComponentEntry] {
        components.filter { $0.minimumTier <= tier }
    }

    /// Get a single component by ID.
    func component(for id: String) -> ComponentEntry? {
        components.first { $0.id == id }
    }

    /// Group components by category.
    func groupedByCategory() -> [(String, [ComponentEntry])] {
        let grouped = Dictionary(grouping: components, by: { $0.category })
        return grouped.sorted { $0.key < $1.key }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        if let manifest = try? JSONDecoder().decode(ComponentManifest.self, from: data) {
            components = manifest.components
            isLoaded = true
        }
    }
}
