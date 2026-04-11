import SwiftUI

/// A single row in the social activity feed list.
///
/// Mirrors the card layout in `web/social.html` — icon, summary,
/// category badge, score dot, relative time.
struct FeedEventRow: View {
    let event: FeedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: icon + actor + time
            HStack(spacing: 8) {
                Text(event.icon ?? "\u{26A1}")
                    .font(.system(size: 18))

                if !event.actor.isEmpty {
                    Text(event.shortActor)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#00cc33"))
                }

                Spacer()

                Text(event.relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Summary
            Text(event.summary)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Meta row: category badge + score + value
            HStack(spacing: 10) {
                Text(event.category ?? "Other")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#00ff41").opacity(0.1))
                    .foregroundColor(Color(hex: "#00cc33"))
                    .cornerRadius(8)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: event.colour ?? "#00ff41"))
                        .frame(width: 6, height: 6)
                    Text(event.scorePercent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let value = event.formattedValue {
                    Text(value)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Tx hash link
            if let tx = event.txHash {
                HStack(spacing: 4) {
                    Text("tx:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(tx.prefix(10))...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#00cc33"))
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0e0e0e"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
        )
    }
}

// MARK: - Color extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 1; b = 0.25
        }
        self.init(red: r, green: g, blue: b)
    }
}

#if DEBUG
struct FeedEventRow_Previews: PreviewProvider {
    static var previews: some View {
        FeedEventRow(event: FeedEvent(
            id: "preview1",
            eventType: "deploy_contract",
            actor: "0x1234567890abcdef1234567890abcdef12345678",
            summary: "0x1234...5678 deployed a smart contract",
            detail: nil,
            component: 1,
            txHash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab",
            valueUsd: 1250.0,
            rarityScore: 0.7,
            timestamp: Date().timeIntervalSince1970 - 300,
            rankedScore: 0.82,
            icon: "\u{1F4DC}",
            colour: "#00ff41",
            category: "Contracts",
            timeAgo: "5m ago"
        ))
        .padding()
        .background(Color(hex: "#0a0a0a"))
        .preferredColorScheme(.dark)
    }
}
#endif
