import AppKit
import Foundation

public enum ClipboardCapture {
    public static func envelope(
        text: String,
        capturedAt: Date = Date(),
        id: UUID = UUID()
    ) -> CaptureEnvelope {
        CaptureEnvelope(
            id: id,
            capturedAt: capturedAt,
            sourceName: "Clipboard.txt",
            contentType: "text/plain",
            data: Data(text.utf8),
            origin: .clipboard
        )
    }

    @MainActor
    public static func readCurrent(
        from pasteboard: NSPasteboard = .general,
        capturedAt: Date = Date()
    ) -> CaptureEnvelope? {
        guard let text = pasteboard.string(forType: .string) else { return nil }
        return envelope(text: text, capturedAt: capturedAt)
    }
}
