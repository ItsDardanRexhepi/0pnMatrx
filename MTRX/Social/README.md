# MTRX Social Feed — iOS Swift Blocks

SwiftUI components for the **Live Activity** tab in the MTRX iOS app.

## Files

| File | Purpose |
|------|---------|
| `FeedEvent.swift` | Data model — maps to `GET /social/feed` JSON |
| `SSEClient.swift` | Server-Sent Events client with auto-reconnect |
| `SocialFeedViewModel.swift` | View model — loading, pagination, filtering, SSE |
| `SocialFeedView.swift` | Main tab view — stats strip, filters, event list |
| `FeedEventRow.swift` | Single event card (icon, summary, score, tx) |
| `TrendingView.swift` | Trending actions sidebar |
| `SocialStatsView.swift` | Feed statistics card |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/social/feed` | GET | Paginated ranked events |
| `/social/feed/stream` | GET | SSE live stream |
| `/social/trending` | GET | Trending actions (24h window) |
| `/social/actor/{wallet}` | GET | Activity for one wallet |
| `/social/stats` | GET | Global feed statistics |

## Integration

Social is **Tab 4** in `MTRXTabView` (Discover, Build, Home, Social, Account). It is already wired — do not add it separately.

```swift
// Already wired in MTRX/App/MTRXTabView.swift as:
SocialFeedView(baseURL: baseURL)
    .tabItem { Label("Social", systemImage: "globe") }
    .tag(Tab.social)
```

The view manages its own lifecycle — connects SSE on appear, disconnects on disappear, supports pull-to-refresh and infinite scroll.

## Design

Matches the 0pnMatrx dark/green aesthetic:
- Background: `#0a0a0a`
- Cards: `#0e0e0e`
- Green accent: `#00ff41`
- Monospace for addresses and scores
