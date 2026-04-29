import TestFlows

enum CaptureFlowSuite: TestFlowRegistry {
    static let title = "Capture"

    static let flows: [TestFlow] = [
        configurationFlow,
        deviceProviderFlow,
    ]
}
