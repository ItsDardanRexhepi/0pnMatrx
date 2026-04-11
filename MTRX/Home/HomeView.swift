import SwiftUI
import Combine

/// The Home tab — Trinity's full-screen chat interface.
///
/// This is the primary tab and the default on launch. Trinity greets
/// the user on first boot with a locked welcome message, then the
/// conversation continues via the gateway's streaming chat endpoint.
///
/// Morpheus appears as a modal overlay when triggered by the
/// conversation context — he is never a separate screen.
struct HomeView: View {

    // MARK: - External state

    let baseURL: URL
    @Binding var pendingMessage: String

    // MARK: - Chat state

    @StateObject private var viewModel: ChatViewModel

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showMorpheusOverlay = false

    init(baseURL: URL, pendingMessage: Binding<String>) {
        self.baseURL = baseURL
        self._pendingMessage = pendingMessage
        self._viewModel = StateObject(wrappedValue: ChatViewModel(baseURL: baseURL))
    }

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0a0a0a")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }

                            if viewModel.isStreaming {
                                streamingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                inputBar
            }

            // Morpheus modal overlay
            if showMorpheusOverlay {
                morpheusOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.showFirstBootIfNeeded()
        }
        .onChange(of: pendingMessage) { newValue in
            if !newValue.isEmpty {
                inputText = newValue
                pendingMessage = ""
                sendMessage()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trinity")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#00ff41"))
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#00ff41"))
                }
            }
            Spacer()
            Button {
                showMorpheusOverlay.toggle()
            } label: {
                Text("M")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ff41"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#1e1e1e"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#0a0a0a"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#1e1e1e")),
            alignment: .bottom
        )
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message Trinity...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "#1e1e1e"))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color(hex: "#333333")
                        : Color(hex: "#00ff41")
                    )
            }
            .disabled(
                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isStreaming
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#0a0a0a"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#1e1e1e")),
            alignment: .top
        )
    }

    // MARK: - Streaming indicator

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(hex: "#00ff41"))
                    .frame(width: 5, height: 5)
                    .opacity(0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: viewModel.isStreaming
                    )
            }
            Spacer()
        }
        .padding(.leading, 16)
    }

    // MARK: - Morpheus overlay

    private var morpheusOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showMorpheusOverlay = false }

            VStack(spacing: 20) {
                HStack {
                    Text("M")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#00ff41"))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: "#1e1e1e"))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morpheus")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Orchestration Agent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        showMorpheusOverlay = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Morpheus coordinates multi-step workflows, DAO governance, and complex multi-agent task delegation. He steps in when a task requires orchestration across multiple services.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#c8c8c8"))
                    .lineSpacing(4)

                HStack(spacing: 12) {
                    statusPill(label: "Workflows", value: "Ready")
                    statusPill(label: "Delegation", value: "Active")
                }
            }
            .padding(24)
            .background(Color(hex: "#0e0e0e"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#1e1e1e"), lineWidth: 1)
            )
            .padding(24)
        }
        .transition(.opacity)
    }

    private func statusPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#00ff41"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "#1a1a1a"))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        viewModel.send(text)
    }
}

// MARK: - Chat message model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: Equatable {
        case user
        case trinity
        case system
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .trinity {
                    Text("Trinity")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#00ff41"))
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .system ? .secondary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(backgroundColor)
                    .cornerRadius(16)
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color(hex: "#00ff41").opacity(0.15)
        case .trinity:
            return Color(hex: "#1e1e1e")
        case .system:
            return Color(hex: "#111111")
        }
    }
}

// MARK: - Chat view model

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false

    private let baseURL: URL
    private let firstBootKey = "trinity_first_boot_shown"
    private var streamTask: Task<Void, Never>?

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Show the first-boot welcome message exactly once.
    func showFirstBootIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: firstBootKey) else { return }
        UserDefaults.standard.set(true, forKey: firstBootKey)

        let welcomeMessage = ChatMessage(
            role: .trinity,
            content: "Hi, my name is Trinity\n\nWelcome to the world of 0pnMatrx, I'll be by your side the entire time if you need me",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }

    /// Send a user message and stream Trinity's response word by word.
    func send(_ text: String) {
        let userMsg = ChatMessage(role: .user, content: text, timestamp: Date())
        messages.append(userMsg)

        // Build the conversation history for the API
        let history: [[String: String]] = messages.compactMap { msg in
            switch msg.role {
            case .user: return ["role": "user", "content": msg.content]
            case .trinity: return ["role": "assistant", "content": msg.content]
            case .system: return nil
            }
        }

        streamTask?.cancel()
        streamTask = Task { await streamResponse(history: history) }
    }

    /// Stream the chat response via POST /chat/stream, appending words
    /// as they arrive so the text appears to type itself.
    private func streamResponse(history: [[String: String]]) async {
        isStreaming = true
        defer { isStreaming = false }

        let trinityMsg = ChatMessage(role: .trinity, content: "", timestamp: Date())
        messages.append(trinityMsg)
        let msgIndex = messages.count - 1

        guard let url = URL(string: baseURL.absoluteString + "/chat/stream") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "messages": history,
            "agent": "trinity",
            "stream": true,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                messages[msgIndex].content = "Connection error. Please try again."
                return
            }

            var accumulated = ""
            for try await line in bytes.lines {
                guard !Task.isCancelled else { break }

                // SSE format: "data: {...}"
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                guard jsonStr != "[DONE]" else { break }

                guard let data = jsonStr.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                // Extract the content delta
                if let choices = parsed["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    accumulated += content
                    messages[msgIndex].content = accumulated
                }

                // Alternative: top-level "content" field
                if let content = parsed["content"] as? String {
                    accumulated += content
                    messages[msgIndex].content = accumulated
                }

                // Alternative: "text" field
                if let text = parsed["text"] as? String, accumulated.isEmpty || content(parsed) {
                    accumulated += text
                    messages[msgIndex].content = accumulated
                }
            }

            // If nothing came through, show a fallback
            if accumulated.isEmpty {
                messages[msgIndex].content = "I'm here. How can I help you?"
            }
        } catch {
            if !Task.isCancelled {
                messages[msgIndex].content = "Connection interrupted. Please try again."
            }
        }
    }

    /// Helper to check if a parsed dict has a "content" key (avoids shadowing).
    private func content(_ dict: [String: Any]) -> Bool {
        dict["content"] != nil
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            baseURL: URL(string: "http://localhost:18790")!,
            pendingMessage: .constant("")
        )
    }
}
#endif
