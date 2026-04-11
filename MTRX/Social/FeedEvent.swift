import Foundation

/// A single social feed event from the 0pnMatrx activity stream.
///
/// Maps 1:1 to the JSON shape returned by `GET /social/feed`.
/// Conforms to `Identifiable` for SwiftUI list rendering and
/// `Codable` for automatic JSON decoding.
struct FeedEvent: Identifiable, Codable, Equatable {
    let id: String
    let eventType: String
    let actor: String
    let summary: String
    let detail: [String: AnyCodable]?
    let component: Int?
    let txHash: String?
    let valueUsd: Double?
    let rarityScore: Double
    let timestamp: Double
    let rankedScore: Double

    // Presentation fields injected by FeedFormatter on the server
    let icon: String?
    let colour: String?
    let category: String?
    let timeAgo: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case actor, summary, detail, component
        case txHash = "tx_hash"
        case valueUsd = "value_usd"
        case rarityScore = "rarity_score"
        case timestamp
        case rankedScore = "ranked_score"
        case icon, colour, category
        case timeAgo = "time_ago"
    }

    /// Short wallet address for display (e.g. "0x1234...abcd").
    var shortActor: String {
        guard actor.count > 10 else { return actor }
        return "\(actor.prefix(6))...\(actor.suffix(4))"
    }

    /// Formatted USD value, or nil if not applicable.
    var formattedValue: String? {
        guard let v = valueUsd, v > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: v))
    }

    /// Human-readable relative time from the event timestamp.
    var relativeTime: String {
        if let t = timeAgo { return t }
        let delta = Date().timeIntervalSince1970 - timestamp
        if delta < 5 { return "just now" }
        if delta < 60 { return "\(Int(delta))s ago" }
        if delta < 3600 { return "\(Int(delta / 60))m ago" }
        if delta < 86400 { return "\(Int(delta / 3600))h ago" }
        return "\(Int(delta / 86400))d ago"
    }

    /// Score as a percentage string (e.g. "78%").
    var scorePercent: String {
        "\(Int(rankedScore * 100))%"
    }
}

// MARK: - AnyCodable helper

/// Lightweight type-erased Codable wrapper for heterogeneous JSON values.
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else if container.decodeNil() { value = NSNull() }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
