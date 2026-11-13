import Foundation
import Testing

@testable import QuickAsk

@MainActor private final class FakeSession: ClaudeSession {
    var isRunning = false
    var sent: [Data] = []
    var stopCount = 0
    func start() throws { isRunning = true }
    func send(_ line: Data) throws { sent.append(line) }
    func stop() {
        isRunning = false
        stopCount += 1
    }
}

private struct StartFailure: Error, LocalizedError {
    var errorDescription: String? { "spawn failed" }
}

@MainActor private final class Harness {
    var sessions: [FakeSession] = []
    var models: [String] = []
    var onEvents: [@MainActor (ClaudeEvent) -> Void] = []
    var onExits: [@MainActor (Int32) -> Void] = []
    var failStart = false
    let defaults: UserDefaults
    var store: ChatStore!

    init() {
        let suite = "ChatStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = ChatStore(defaults: defaults) { [unowned self] model, onEvent, onExit in
            if failStart { throw StartFailure() }
            let fake = FakeSession()
            sessions.append(fake)
            models.append(model)
            onEvents.append(onEvent)
            onExits.append(onExit)
            return fake
        }
    }
}

private func result(
    cumulative: Double, output: Int = 1, isError: Bool = false, errorText: String? = nil,
    models: [String] = []
) -> TurnResult {
    TurnResult(
        isError: isError, errorText: errorText, cumulativeCostUsd: cumulative,
        usage: TurnUsage(inputTokens: 1, outputTokens: output, cacheReadTokens: 0, cacheWriteTokens: 0),
        models: models)
}

@MainActor @Test func streamsAndPricesTwoTurns() throws {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.handle(.textDelta("Hel"))
    store.handle(.textDelta("lo"))
    store.handle(.turnResult(result(cumulative: 0.002, output: 5)))
    store.send(text: "again", images: [])
    store.handle(.textDelta("ok"))
    store.handle(.turnResult(result(cumulative: 0.0025, output: 1)))
    #expect(store.messages.map(\.text) == ["hi", "Hello", "again", "ok"])
    #expect(abs(store.messages[3].cost!.totalUsd - 0.0005) < 1e-9)
    #expect(abs(store.totalCostUsd - 0.0025) < 1e-9)
    #expect(harness.sessions.count == 1)
    #expect(harness.sessions[0].sent.count == 2 && !store.isResponding)
}

@MainActor @Test func exitMidTurnShowsErrorAndResetsCumulative() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.handleExit(status: 1)
    #expect(store.messages.last?.role == .error)
    #expect(store.messages.last?.text == "claude exited (code 1), next message starts a new conversation")
    #expect(store.messages.map(\.role) == [.user, .error])
    #expect(!store.isResponding)

    store.send(text: "again", images: [])
    #expect(harness.sessions.count == 2)
    store.handle(.textDelta("ok"))
    store.handle(.turnResult(result(cumulative: 0.001)))
    #expect(abs(store.totalCostUsd - 0.001) < 1e-9)
    #expect(abs(store.messages.last!.cost!.totalUsd - 0.001) < 1e-9)
}

@MainActor @Test func modelPickSavedAndLockedAfterFirstMessage() {
    let harness = Harness()
    let store = harness.store!
    #expect(store.canSelectModel)
    store.selectModel("haiku")
    #expect(store.model == "haiku")
    #expect(harness.defaults.string(forKey: SettingsKey.defaultModel) == "haiku")
    store.send(text: "hi", images: [])
    #expect(harness.models == ["haiku"])
    #expect(!store.canSelectModel)
    store.selectModel("opus")
    #expect(store.model == "haiku")
    store.newChat()
    #expect(store.model == "haiku")
    #expect(store.canSelectModel)
}

@MainActor @Test func newChatClearsAndStops() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.handle(.textDelta("yo"))
    store.handle(.turnResult(result(cumulative: 0.01)))
    let oldID = store.chatID
    store.newChat()
    #expect(store.messages.isEmpty)
    #expect(store.totalCostUsd == 0)
    #expect(!store.isResponding)
    #expect(store.chatID != oldID)
    #expect(harness.sessions[0].stopCount == 1)
    store.send(text: "fresh", images: [])
    store.handle(.textDelta("ok"))
    store.handle(.turnResult(result(cumulative: 0.004)))
    #expect(abs(store.totalCostUsd - 0.004) < 1e-9)
}

@MainActor @Test func sendIgnoredWhileResponding() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.send(text: "second", images: [])
    #expect(store.messages.count == 2)
    #expect(harness.sessions[0].sent.count == 1)
    store.handle(.turnResult(result(cumulative: 0.001)))
    store.send(text: "   ", images: [])
    #expect(harness.sessions[0].sent.count == 1)
}

@MainActor @Test func lateEventsFromStoppedSessionAreIgnored() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    let oldEvent = harness.onEvents[0]
    let oldExit = harness.onExits[0]
    store.newChat()
    store.send(text: "again", images: [])
    oldEvent(.turnResult(result(cumulative: 0.5)))
    oldExit(1)
    #expect(store.totalCostUsd == 0)
    #expect(store.messages.map(\.role) == [.user, .assistant])
    #expect(store.isResponding)
}

@MainActor @Test func errorTurnDoesNotOverwritePreviousCaption() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.handle(.textDelta("Hello"))
    store.handle(.turnResult(result(cumulative: 0.002)))
    let firstCost = store.messages[1].cost
    #expect(firstCost != nil)
    store.send(text: "again", images: [])
    store.handle(.turnResult(result(cumulative: 0.002, isError: true, errorText: "overloaded")))
    #expect(store.messages[1].cost == firstCost)
    #expect(store.messages.last?.role == .error)
    #expect(store.messages.last?.text == "overloaded")
    #expect(!store.isResponding)
}

@MainActor @Test func startFailureShowsErrorAndDropsAssistantMessage() {
    let harness = Harness()
    let store = harness.store!
    harness.failStart = true
    store.send(text: "hi", images: [])
    #expect(store.messages.map(\.role) == [.user, .error])
    #expect(store.messages.last?.text == "spawn failed")
    #expect(!store.isResponding)
}

@MainActor @Test func costModelPrefersChosenAlias() {
    let harness = Harness()
    let store = harness.store!
    store.send(text: "hi", images: [])
    store.handle(.textDelta("ok"))
    store.handle(
        .turnResult(result(cumulative: 0.001, models: ["claude-haiku-5-5", "claude-sonnet-5-5"])))
    #expect(store.messages[1].cost?.model == "claude-sonnet-5-5")
}
