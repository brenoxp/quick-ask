import Testing

@testable import QuickAsk

@Test func costText() {
    #expect(CostFormat.costText(0.1234) == "$0.12")
    #expect(CostFormat.costText(0.0024) == "$0.002")
    #expect(CostFormat.costText(0) == "$0.00")
    #expect(CostFormat.costText(0.0003) == "<$0.001")
}

@Test func tokenText() {
    #expect(CostFormat.tokenText(950) == "950")
    #expect(CostFormat.tokenText(36_400) == "36k")
    #expect(CostFormat.tokenText(1_000_000) == "1M")
    #expect(CostFormat.tokenText(1_250_000) == "1.2M")
}

@Test func captionWithAndWithoutTokens() {
    let cost = TurnCost(totalUsd: 0.1, usage: TurnUsage(inputTokens: 6, outputTokens: 382, cacheReadTokens: 72_000, cacheWriteTokens: 0), model: "claude-sonnet-5-5")
    #expect(CostFormat.caption(cost, showsTokens: true) == "$0.10 · in 6 · out 382 · c_read 72k")
    #expect(CostFormat.caption(cost, showsTokens: false) == "$0.10")
}

@Test func helpNamesModelAndLabels() {
    let cost = TurnCost(totalUsd: 0.1, usage: TurnUsage(inputTokens: 1, outputTokens: 1, cacheReadTokens: 0, cacheWriteTokens: 0), model: "claude-sonnet-5-5")
    #expect(CostFormat.help(cost).contains("claude-sonnet-5-5"))
    #expect(CostFormat.help(cost).contains("c_write: tokens written to the prompt cache"))
}
