import Observation

// UI signals shared by the panel's views. Each change of `focusRequest` asks the composer to take keyboard focus.
@MainActor @Observable final class PanelUIState {
    private(set) var focusRequest = 0

    func requestInputFocus() { focusRequest += 1 }
}
