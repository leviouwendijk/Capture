import TestFlows

@main
enum CaptureTestFlowsMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: CaptureFlowSuite.self
        )
    }
}
