import Testing
@testable import CAMAssistantApp

@Test("successful capture uses an ordinary Library confirmation")
func successfulCaptureUsesOrdinaryLibraryConfirmation() {
    #expect(
        CaptureNotice.saved("Meeting Notes.txt").message
            == "Saved Meeting Notes.txt to your Library."
    )
}

@Test("duplicate capture reassures without exposing storage internals")
func duplicateCaptureUsesFriendlyCopy() {
    #expect(
        CaptureNotice.alreadySaved("Meeting Notes.txt").message
            == "Meeting Notes.txt is already in your Library."
    )
}

@Test("capture failure offers recovery and protects the original")
func captureFailureOffersSafeRecovery() {
    let notice = CaptureNotice.failed(
        itemName: "Meeting Notes.txt",
        technicalDetails: "ingest-write-failed"
    )

    #expect(notice.canRetry)
    #expect(notice.contentSafetyMessage == "Your original content was not changed.")
    #expect(notice.technicalDetails == "ingest-write-failed")
    #expect(!notice.message.localizedCaseInsensitiveContains("ingest"))
}

@Test("empty clipboard explains the next action")
func emptyClipboardExplainsNextAction() {
    #expect(CaptureNotice.emptyClipboard.message == "Copy some text, then try Save Clipboard again.")
    #expect(CaptureNotice.emptyClipboard.canRetry)
}
