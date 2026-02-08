import Abstractions
import Testing
@testable import UIComponents

@Suite("OpenClaw Status Presenter Tests")
internal struct OpenClawStatusPresenterTests {
    @Test("No active instance maps to Off style")
    func noActiveIsOff() {
        let style: OpenClawStatusStyle = OpenClawStatusPresenter.style(
            hasActiveInstance: false,
            status: .idle
        )
        #expect(style.label == "OpenClaw: Off")
        #expect(style.symbolName == "antenna.radiowaves.left.and.right.slash")
        #expect(style.level == .neutral)
    }

    @Test("Connected maps to ok style")
    func connectedIsOk() {
        let style: OpenClawStatusStyle = OpenClawStatusPresenter.style(
            hasActiveInstance: true,
            status: .connected
        )
        #expect(style.label == "OpenClaw: Connected")
        #expect(style.level == .success)
    }

    @Test("Pairing required maps to warning style")
    func pairingRequiredIsWarning() {
        let style: OpenClawStatusStyle = OpenClawStatusPresenter.style(
            hasActiveInstance: true,
            status: .pairingRequired(requestId: "req-1")
        )
        #expect(style.label == "OpenClaw: Pairing Required")
        #expect(style.level == .warning)
    }

    @Test("Failed maps to error style")
    func failedIsError() {
        let style: OpenClawStatusStyle = OpenClawStatusPresenter.style(
            hasActiveInstance: true,
            status: .failed(message: "boom")
        )
        #expect(style.label == "OpenClaw: Failed")
        #expect(style.level == .error)
    }
}
