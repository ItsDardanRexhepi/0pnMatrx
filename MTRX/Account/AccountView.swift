import SwiftUI

/// The Account tab — wallet, subscription, settings, and preferences.
///
/// Sections:
///   - Wallet address (truncated, tap to copy)
///   - Subscription tier badge + usage bars
///   - Upgrade button (Free tier only)
///   - Manage Subscription
///   - Referral code (display, copy, share)
///   - Notification preferences toggle
///   - Privacy settings (on-device inference preference)
///   - About (version, Privacy Policy, Terms)
///   - Disconnect wallet
struct AccountView: View {

    let baseURL: URL

    @State private var gate = FeatureGate.shared
    @State private var walletAddress = UserDefaults.standard.string(forKey: "wallet_address") ?? ""
    @State private var referralCode = UserDefaults.standard.string(forKey: "referral_code") ?? ""
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    @State private var onDeviceInference = UserDefaults.standard.bool(forKey: "on_device_inference")
    @State private var showUpgrade = false
    @State private var showSubscriptionStatus = false
    @State private var showDisconnectAlert = false
    @State private var copiedWallet = false
    @State private var copiedReferral = false

    // Usage data (fetched from gateway)
    @State private var usageData: [UsageItem] = []

    var body: some View {
        NavigationStack {
            List {
                // ── Wallet ────────────────────────────────────────
                Section {
                    walletRow
                } header: {
                    Text("Wallet")
                }

                // ── Subscription ──────────────────────────────────
                Section {
                    tierBadge
                    if gate.currentTier == .free {
                        upgradeRow
                    }
                    manageSubscriptionRow
                } header: {
                    Text("Subscription")
                }

                // ── Usage ─────────────────────────────────────────
                if !usageData.isEmpty {
                    Section {
                        ForEach(usageData) { item in
                            usageRow(item)
                        }
                    } header: {
                        Text("Usage This Month")
                    }
                }

                // ── Referral ──────────────────────────────────────
                Section {
                    referralRow
                } header: {
                    Text("Referral")
                }

                // ── Preferences ───────────────────────────────────
                Section {
                    notificationToggle
                    privacyToggle
                } header: {
                    Text("Preferences")
                }

                // ── About ─────────────────────────────────────────
                Section {
                    aboutRow(title: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    linkRow(title: "Privacy Policy", url: "https://openmatrix.io/privacy")
                    linkRow(title: "Terms of Service", url: "https://openmatrix.io/terms")
                } header: {
                    Text("About")
                }

                // ── Disconnect ────────────────────────────────────
                Section {
                    disconnectRow
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0a0a0a"))
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showUpgrade) {
                UpgradeView(
                    blockedFeature: .contractConversion,
                    currentUsage: 0,
                    limit: 5
                )
            }
            .sheet(isPresented: $showSubscriptionStatus) {
                SubscriptionStatusView()
            }
            .alert("Disconnect Wallet", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) { disconnectWallet() }
            } message: {
                Text("This will sign you out and clear your local session. Your on-chain data remains unaffected.")
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadUsage()
            await loadReferralCode()
        }
    }

    // MARK: - Wallet

    private var walletRow: some View {
        Button {
            guard !walletAddress.isEmpty else { return }
            UIPasteboard.general.string = walletAddress
            copiedWallet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedWallet = false }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wallet.pass")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#00ff41"))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(walletAddress.isEmpty ? "No wallet connected" : truncatedAddress)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(walletAddress.isEmpty ? .secondary : .white)
                    Text(copiedWallet ? "Copied!" : "Tap to copy full address")
                        .font(.system(size: 11))
                        .foregroundColor(copiedWallet ? Color(hex: "#00ff41") : .secondary)
                }
                Spacer()
                if !walletAddress.isEmpty {
                    Image(systemName: copiedWallet ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(copiedWallet ? Color(hex: "#00ff41") : .secondary)
                }
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    private var truncatedAddress: String {
        guard walletAddress.count > 10 else { return walletAddress }
        return "\(walletAddress.prefix(6))...\(walletAddress.suffix(4))"
    }

    // MARK: - Subscription

    private var tierBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: tierIcon)
                .font(.system(size: 20))
                .foregroundColor(gate.currentTier.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(gate.currentTier.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(gate.currentTier.priceDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Active")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#00ff41"), in: Capsule())
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    private var tierIcon: String {
        switch gate.currentTier {
        case .free: return "person.circle"
        case .pro: return "star.circle.fill"
        case .enterprise: return "building.2.crop.circle.fill"
        }
    }

    private var upgradeRow: some View {
        Button {
            showUpgrade = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(Color(hex: "#00ff41"))
                Text("Upgrade to Pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#00ff41"))
                Spacer()
                Text("$4.99/mo")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(hex: "#00ff41").opacity(0.08))
    }

    private var manageSubscriptionRow: some View {
        Button {
            showSubscriptionStatus = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                Text("Manage Subscription")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Usage

    private func usageRow(_ item: UsageItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Spacer()
                Text("\(item.used) / \(item.limit == -1 ? "\u{221E}" : "\(item.limit)")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if item.limit > 0 {
                ProgressView(value: Double(item.used), total: Double(item.limit))
                    .tint(item.progress > 0.8 ? .red : Color(hex: "#00ff41"))
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Referral

    private var referralRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift")
                .foregroundColor(Color(hex: "#00ff41"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(referralCode.isEmpty ? "No referral code" : referralCode)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(referralCode.isEmpty ? .secondary : .white)
                if copiedReferral {
                    Text("Copied!")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#00ff41"))
                }
            }
            Spacer()
            if !referralCode.isEmpty {
                Button {
                    UIPasteboard.general.string = referralCode
                    copiedReferral = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedReferral = false }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                ShareLink(item: "Join me on 0pnMatrx! Use my referral code: \(referralCode)\nhttps://openmatrix.io/ref/\(referralCode)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Preferences

    private var notificationToggle: some View {
        Toggle(isOn: $notificationsEnabled) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .foregroundColor(Color(hex: "#00ff41"))
                    .frame(width: 28)
                Text("Notifications")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .tint(Color(hex: "#00ff41"))
        .onChange(of: notificationsEnabled) { newValue in
            UserDefaults.standard.set(newValue, forKey: "notifications_enabled")
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    private var privacyToggle: some View {
        Toggle(isOn: $onDeviceInference) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundColor(Color(hex: "#00ff41"))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("On-Device Inference")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("Process data locally when possible")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(Color(hex: "#00ff41"))
        .onChange(of: onDeviceInference) { newValue in
            UserDefaults.standard.set(newValue, forKey: "on_device_inference")
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - About

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    private func linkRow(title: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Disconnect

    private var disconnectRow: some View {
        Button {
            showDisconnectAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Disconnect Wallet")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Actions

    private func disconnectWallet() {
        walletAddress = ""
        UserDefaults.standard.removeObject(forKey: "wallet_address")
        UserDefaults.standard.removeObject(forKey: "wallet_session_token")
        gate.currentTier = .free
    }

    // MARK: - Network

    private func loadUsage() async {
        // Build usage items from FeatureGate limits
        let features: [(Feature, String)] = [
            (.contractConversion, "Contract Conversions"),
            (.nftMinting, "NFT Mints"),
            (.marketplaceListing, "Marketplace Listings"),
            (.governanceVoting, "Governance Votes"),
        ]

        usageData = features.compactMap { feature, name in
            let limit = feature.limit(for: gate.currentTier)
            return UsageItem(
                id: feature.rawValue,
                name: name,
                used: 0,  // Replace with actual usage from gateway
                limit: limit ?? -1
            )
        }
    }

    private func loadReferralCode() async {
        guard !walletAddress.isEmpty else { return }
        guard let url = URL(string: baseURL.absoluteString + "/referral/stats") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["referral_code"] as? String {
                referralCode = code
                UserDefaults.standard.set(code, forKey: "referral_code")
            }
        } catch {
            print("[Account] Failed to load referral code: \(error)")
        }
    }
}

// MARK: - Usage model

struct UsageItem: Identifiable {
    let id: String
    let name: String
    let used: Int
    let limit: Int

    var progress: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }
}

#if DEBUG
struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView(baseURL: URL(string: "http://localhost:18790")!)
    }
}
#endif
