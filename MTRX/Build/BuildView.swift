import SwiftUI

/// The Build tab — developer tools and power-user features.
///
/// Sections:
///   - Deploy a Contract — describe a contract in plain text
///   - My Plugins — purchased marketplace plugins
///   - Browse Marketplace — links to openmatrix.io/marketplace
///   - SDK Docs — links to openmatrix.io/learn
///   - Certifications — links to openmatrix.io/certification
struct BuildView: View {

    let baseURL: URL

    @State private var contractDescription = ""
    @State private var isDeploying = false
    @State private var deployResult: String?
    @State private var purchasedPlugins: [PurchasedPlugin] = []
    @State private var isLoadingPlugins = false

    var body: some View {
        NavigationStack {
            List {
                // ── Deploy a Contract ─────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Describe your contract", systemImage: "doc.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#00ff41"))

                        TextEditor(text: $contractDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color(hex: "#1a1a1a"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#2a2a2a"), lineWidth: 1)
                            )

                        if let result = deployResult {
                            Text(result)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(
                                    result.contains("Error") ? .red : Color(hex: "#00ff41")
                                )
                                .padding(8)
                                .background(Color(hex: "#111111"))
                                .cornerRadius(8)
                        }

                        Button {
                            Task { await deployContract() }
                        } label: {
                            HStack {
                                if isDeploying {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.8)
                                }
                                Text(isDeploying ? "Converting..." : "Convert to Smart Contract")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#00ff41"))
                        .foregroundStyle(.black)
                        .disabled(
                            contractDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isDeploying
                        )
                    }
                    .listRowBackground(Color(hex: "#0e0e0e"))
                } header: {
                    Text("Deploy a Contract")
                }

                // ── My Plugins ────────────────────────────────────
                Section {
                    if isLoadingPlugins {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(Color(hex: "#00ff41"))
                            Spacer()
                        }
                        .listRowBackground(Color(hex: "#0e0e0e"))
                    } else if purchasedPlugins.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundColor(.secondary)
                            Text("No plugins purchased yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color(hex: "#0e0e0e"))
                    } else {
                        ForEach(purchasedPlugins) { plugin in
                            HStack(spacing: 12) {
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .foregroundColor(Color(hex: "#00ff41"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plugin.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(plugin.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(Color(hex: "#0e0e0e"))
                        }
                    }
                } header: {
                    Text("My Plugins")
                }

                // ── External links ────────────────────────────────
                Section {
                    linkRow(
                        icon: "storefront",
                        title: "Browse Marketplace",
                        subtitle: "Discover plugins and extensions",
                        url: "https://openmatrix.io/marketplace"
                    )
                    linkRow(
                        icon: "book.closed",
                        title: "SDK Docs",
                        subtitle: "Build on the 0pnMatrx platform",
                        url: "https://openmatrix.io/learn"
                    )
                    linkRow(
                        icon: "checkmark.seal",
                        title: "Certifications",
                        subtitle: "Earn blockchain development credentials",
                        url: "https://openmatrix.io/certification"
                    )
                } header: {
                    Text("Resources")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0a0a0a"))
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await loadPurchasedPlugins()
        }
    }

    // MARK: - Link row

    private func linkRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#00ff41"))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(hex: "#0e0e0e"))
    }

    // MARK: - Network

    private func deployContract() async {
        let text = contractDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isDeploying = true
        deployResult = nil
        defer { isDeploying = false }

        guard let url = URL(string: baseURL.absoluteString + "/chat") else {
            deployResult = "Error: Invalid gateway URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "messages": [
                ["role": "user", "content": "Convert this contract to a smart contract: \(text)"]
            ],
            "agent": "trinity",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                deployResult = "Error: Server returned an error"
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["response"] as? String {
                deployResult = reply
            } else {
                deployResult = "Contract conversion request sent to Trinity."
            }
        } catch {
            deployResult = "Error: \(error.localizedDescription)"
        }
    }

    private func loadPurchasedPlugins() async {
        isLoadingPlugins = true
        defer { isLoadingPlugins = false }

        guard let url = URL(string: baseURL.absoluteString + "/marketplace/purchased") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let plugins = json["plugins"] as? [[String: Any]] {
                purchasedPlugins = plugins.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String else { return nil }
                    return PurchasedPlugin(
                        id: id,
                        name: name,
                        description: dict["description"] as? String ?? ""
                    )
                }
            }
        } catch {
            print("[Build] Failed to load purchased plugins: \(error)")
        }
    }
}

// MARK: - Plugin model

struct PurchasedPlugin: Identifiable {
    let id: String
    let name: String
    let description: String
}

#if DEBUG
struct BuildView_Previews: PreviewProvider {
    static var previews: some View {
        BuildView(baseURL: URL(string: "http://localhost:18790")!)
    }
}
#endif
