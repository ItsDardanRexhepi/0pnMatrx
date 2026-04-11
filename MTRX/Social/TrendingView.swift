import SwiftUI

/// Displays trending actions from the social feed.
///
/// Used as a standalone section within ``SocialFeedView`` on iPhone
/// or as a sidebar panel on iPad. Fetches data from `GET /social/trending`.
struct TrendingView: View {
    let trending: [TrendingAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("TRENDING")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "#00cc33"))
                .padding(.bottom, 12)

            if trending.isEmpty {
                Text("No trending actions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(trending.prefix(10)) { action in
                    trendingRow(action)
                }
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

    // MARK: - Row

    private func trendingRow(_ action: TrendingAction) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.label)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text("\(action.uniqueActors) actors")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        if let maxVal = action.maxValueUsd, maxVal > 0 {
                            Text("up to $\(Int(maxVal).formatted())")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Text("\(action.count)x")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ff41"))
            }
            .padding(.vertical, 10)

            Divider()
                .background(Color(hex: "#1e1e1e"))
        }
    }
}

#if DEBUG
struct TrendingView_Previews: PreviewProvider {
    static var previews: some View {
        TrendingView(trending: [
            TrendingAction(
                eventType: "swap_tokens", label: "swapped tokens",
                count: 42, avgScore: 0.65, maxValueUsd: 12500,
                uniqueActors: 18
            ),
            TrendingAction(
                eventType: "deploy_contract", label: "deployed a smart contract",
                count: 15, avgScore: 0.78, maxValueUsd: nil,
                uniqueActors: 12
            ),
        ])
        .padding()
        .background(Color(hex: "#0a0a0a"))
        .preferredColorScheme(.dark)
    }
}
#endif
