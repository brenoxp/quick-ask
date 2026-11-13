import Foundation
import Observation

// Conversation state for the whole app: messages, the running claude session, per-turn cost and the model choice.
@MainActor @Observable final class ChatStore {
    typealias SessionFactory = @MainActor (
        _ model: String,
        _ onEvent: @escaping @MainActor (ClaudeEvent) -> Void,
        _ onExit: @escaping @MainActor (Int32) -> Void
    ) throws -> ClaudeSession

    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false
    private(set) var model: String
    private(set) var totalCostUsd: Double = 0
    private(set) var chatID = UUID()

    var canSelectModel: Bool { messages.isEmpty }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let makeSession: SessionFactory
    @ObservationIgnored private var session: ClaudeSession?
    // Bumped on every session start, newChat and exit; callbacks from an older generation are dropped.
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var inFlightAssistantID: UUID?
    // The previous result's cumulative process cost; the next turn costs the difference.
    @ObservationIgnored private var lastCumulative: Double = 0

    init(defaults: UserDefaults = .standard, makeSession: @escaping SessionFactory) {
        self.defaults = defaults
        self.makeSession = makeSession
        self.model = Self.savedModel(defaults)
    }

    static func live(defaults: UserDefaults = .standard) -> ChatStore {
        ChatStore(defaults: defaults) { model, onEvent, onExit in
            ClaudeProcess(
                configuration: try .fromSettings(defaults, model: model),
                onEvent: onEvent,
                onExit: onExit
            )
        }
    }

    func send(text: String, images: [ImageAttachment]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isResponding, !(trimmed.isEmpty && images.isEmpty) else { return }

        messages.append(ChatMessage(role: .user, text: text, images: images))
        let assistant = ChatMessage(role: .assistant, text: "")
        messages.append(assistant)
        inFlightAssistantID = assistant.id
        isResponding = true

        do {
            let running = try runningSession()
            try running.send(StreamProtocol.userMessage(text: text, images: images.map(\.payload)))
        } catch {
            FileLog.error("send failed: \(error.localizedDescription)")
            removeMessage(id: assistant.id)
            inFlightAssistantID = nil
            isResponding = false
            messages.append(ChatMessage(role: .error, text: error.localizedDescription))
        }
    }

    func newChat() {
        sessionGeneration += 1
        session?.stop()
        session = nil
        chatID = UUID()
        messages = []
        totalCostUsd = 0
        lastCumulative = 0
        isResponding = false
        inFlightAssistantID = nil
        model = Self.savedModel(defaults)
    }

    func selectModel(_ model: String) {
        guard canSelectModel else { return }
        self.model = model
        defaults.set(model, forKey: SettingsKey.defaultModel)
    }

    func handle(_ event: ClaudeEvent) {
        switch event {
        case .textDelta(let chunk):
            guard let id = inFlightAssistantID, let index = index(of: id) else { return }
            messages[index].text += chunk
        case .turnResult(let result):
            finishTurn(result)
        }
    }

    func handleExit(status: Int32) {
        sessionGeneration += 1
        session = nil
        lastCumulative = 0
        guard let id = inFlightAssistantID else { return }
        removeMessageIfEmpty(id: id)
        inFlightAssistantID = nil
        isResponding = false
        messages.append(
            ChatMessage(
                role: .error,
                text: "claude exited (code \(status)), next message starts a new conversation"))
    }

    // MARK: - Private

    private static func savedModel(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: SettingsKey.defaultModel) ?? SettingsDefault.defaultModel
    }

    // The live session, or a freshly started one when none is running.
    private func runningSession() throws -> ClaudeSession {
        if let session, session.isRunning { return session }
        session?.stop()
        session = nil
        sessionGeneration += 1
        let generation = sessionGeneration
        let created = try makeSession(
            model,
            { [weak self] event in
                guard let self, self.sessionGeneration == generation else { return }
                self.handle(event)
            },
            { [weak self] status in
                guard let self, self.sessionGeneration == generation else { return }
                self.handleExit(status: status)
            })
        try created.start()
        session = created
        return created
    }

    private func finishTurn(_ result: TurnResult) {
        guard let id = inFlightAssistantID else { return }
        let turnUsd = max(0, result.cumulativeCostUsd - lastCumulative)
        lastCumulative = result.cumulativeCostUsd
        totalCostUsd += turnUsd

        if let index = index(of: id) {
            messages[index].cost = TurnCost(
                totalUsd: turnUsd, usage: result.usage, model: servingModel(in: result.models))
        }
        removeMessageIfEmpty(id: id)
        if result.isError {
            messages.append(ChatMessage(role: .error, text: result.errorText ?? "Unknown error"))
        }
        inFlightAssistantID = nil
        isResponding = false
    }

    private func servingModel(in models: [String]) -> String {
        let alias = model.lowercased()
        return models.first { $0.lowercased().contains(alias) } ?? models.sorted().first ?? model
    }

    private func index(of id: UUID) -> Int? {
        messages.firstIndex { $0.id == id }
    }

    private func removeMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }

    private func removeMessageIfEmpty(id: UUID) {
        if let index = index(of: id), messages[index].text.isEmpty { messages.remove(at: index) }
    }
}
