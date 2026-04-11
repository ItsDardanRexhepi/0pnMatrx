import SwiftUI

/// Compact stats card for the social feed sidebar.
///
/// Displays total events, average score, and the most active actor.
/// Matches the "Feed Stats" sidebar card in `web/social.html`.
struct SocialStatsView: View {
    let stats: FeedStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("FEED STATS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "#00cc33"))
                .padding(.bottom, 12)

            statRow(label: "Avg Score",
                    value: "\(Int(stats.avgScore * 100))%",
                    valueColor: Color(hex: "#00ff41"))

            Divider().background(Color(hex: "#1e1e1e"))

            statRow(label: "Total Events",
                    value: stats.totalEvents.formatted())

            Divider().background(Color(hex: "#1e1e1e"))

            statRow(label: "Unique Actors",
                    value: stats.uniqueActors.formatted())

            Divider().background(Color(hex: "#1e1e1e"))

            statRow(label: "Last 24h",
                    value: stats.eventsLast24h.formatted(),
                    valueColor: Color(hex: "#00ff41"))

            if let top = stats.mostActiveActor {
                Divider().background(Color(hex: "#1e1e1e"))

                HStack {
                    Text("Top Actor")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(shortAddr(top.address))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#00cc33"))
                        Text("\(top.eventCount) events")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(hex: "#0e0e0e"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func statRow(
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 8)
    }

    private func shortAddr(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
}

#if DEBUG
struct SocialStatsView_Previews: PreviewProvider {
    static var previews: some View {
        SocialStatsView(stats: FeedStats(
            totalEvents: 1234,
            uniqueActors: 89,
            uniqueActionTypes: 24,
            eventsLast24h: 156,
            avgScore: 0.623,
            mostActiveActor: FeedStats.MostActiveActor(
                address: "0x1234567890abcdef1234567890abcdef12345678",
                eventCount: 42
            )
        ))
        .padding()
        .background(Color(hex: "#0a0a0a"))
        .preferredColorScheme(.dark)
    }
}
#endif
