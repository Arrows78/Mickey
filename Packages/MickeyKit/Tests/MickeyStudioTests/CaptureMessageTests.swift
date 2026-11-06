import Foundation
import ScreenCaptureKit
import Testing
@testable import MickeyStudio

@Suite("Capture messages")
struct CaptureMessageTests {
    @Test func aMissingPermissionSaysWhatToDo() {
        let error = NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture"])
        let message = ScreenCapture.userMessage(for: error)
        #expect(message.contains("Screen Recording"))
        #expect(!message.contains("TCC"))
    }

    @Test func anyOtherFailureKeepsTheSystemText() {
        let error = NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Something broke"])
        #expect(ScreenCapture.userMessage(for: error) == "Zoom and loupe: Something broke")
    }
}
