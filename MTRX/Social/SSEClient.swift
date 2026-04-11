import Foundation
import Combine

/// Lightweight Server-Sent Events client for the 0pnMatrx feed stream.
///
/// Connects to `GET /social/feed/stream` and publishes decoded
/// ``FeedEvent`` values through a Combine publisher. Handles automatic
/// reconnection with exponential back-off.
///
/// Usage:
/// ```swift
/// let client = SSEClient(baseURL: URL(string: "https://api.0pnmatrx.io")!)
/// client.connect()
/// client.events.sink { event in print(event.summary) }
/// ```
final class SSEClient: NSObject, ObservableObject, URLSessionDataDelegate {

    // MARK: - Published state

    @Published private(set) var isConnected = false

    /// Combine subject that emits every new feed event.
    let events = PassthroughSubject<FeedEvent, Never>()

    // MARK: - Configuration

    private let baseURL: URL
    private let path = "/social/feed/stream"
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var retryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0
    private var isManuallyDisconnected = false

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(baseURL: URL) {
        self.baseURL = baseURL
        super.init()
    }

    deinit {
        disconnect()
    }

    // MARK: - Public API

    func connect() {
        isManuallyDisconnected = false
        retryDelay = 1.0
        startConnection()
    }

    func disconnect() {
        isManuallyDisconnected = true
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    // MARK: - Internal

    private func startConnection() {
        guard !isManuallyDisconnected else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        task = session?.dataTask(with: request)
        task?.resume()
    }

    private func scheduleReconnect() {
        guard !isManuallyDisconnected else { return }
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startConnection()
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        isConnected = true
        retryDelay = 1.0
        buffer = Data()
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        buffer.append(data)
        processBuffer()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        isConnected = false
        scheduleReconnect()
    }

    // MARK: - SSE parsing

    /// Parse the SSE buffer line-by-line, extracting `data:` fields
    /// from `event: feed` blocks.
    private func processBuffer() {
        guard let text = String(data: buffer, encoding: .utf8) else { return }

        let blocks = text.components(separatedBy: "\n\n")
        // Keep the last incomplete block in the buffer
        if !text.hasSuffix("\n\n"), let last = blocks.last {
            buffer = last.data(using: .utf8) ?? Data()
        } else {
            buffer = Data()
        }

        let completeBlocks = text.hasSuffix("\n\n") ? blocks : Array(blocks.dropLast())
        for block in completeBlocks where !block.isEmpty {
            parseSSEBlock(block)
        }
    }

    private func parseSSEBlock(_ block: String) {
        var eventType: String?
        var dataLines: [String] = []

        for line in block.components(separatedBy: "\n") {
            if line.hasPrefix("event:") {
                eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        guard eventType == "feed", !dataLines.isEmpty else { return }
        let jsonString = dataLines.joined()
        guard let jsonData = jsonString.data(using: .utf8) else { return }

        // The SSE payload wraps the event inside a BroadcastEvent envelope;
        // the actual FeedEvent fields are inside `payload`.
        struct Envelope: Decodable {
            let payload: FeedEvent?
        }

        // Try envelope first, then raw FeedEvent
        if let envelope = try? decoder.decode(Envelope.self, from: jsonData),
           let event = envelope.payload {
            events.send(event)
        } else if let event = try? decoder.decode(FeedEvent.self, from: jsonData) {
            events.send(event)
        }
    }
}
