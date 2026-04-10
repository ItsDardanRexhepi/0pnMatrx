// MTRX/Subscriptions/PlatformFeeDisclosure.swift
// Copy this file to the MTRX iOS app's Subscriptions group.

import SwiftUI

/// One-time disclosure shown before a user's first transaction of each type.
///
/// Explains the on-chain platform fee clearly and honestly.
/// Stored in UserDefaults so it only shows once per action category.
struct PlatformFeeDisclosure: View {
    let actionType: String
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accepted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: 0x00FF41))

            Text("Platform Fee Disclosure")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 12) {
                infoRow(
                    icon: "arrow.right.circle",
                    text: "A small platform fee is included in this transaction."
                )
                infoRow(
                    icon: "building.columns",
                    text: "This fee routes to the NeoSafe multisig wallet and funds platform development."
                )
                infoRow(
                    icon: "eye",
                    text: "All fees are fully transparent and verifiable on-chain."
                )
                infoRow(
                    icon: "shield.checkered",
                    text: "Fee amounts are fixed per action type and never change without notice."
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("NeoSafe: 0x46fF...8Ec5")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Button {
                accepted = true
                markDisclosed(actionType)
                onAccept()
                dismiss()
            } label: {
                Text("I Understand")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x00FF41))
            .foregroundStyle(.black)

            Button("Cancel") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0x00FF41))
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Persistence

    static func needsDisclosure(for actionType: String) -> Bool {
        !UserDefaults.standard.bool(forKey: "fee_disclosed_\(actionType)")
    }

    private func markDisclosed(_ actionType: String) {
        UserDefaults.standard.set(true, forKey: "fee_disclosed_\(actionType)")
    }
}
