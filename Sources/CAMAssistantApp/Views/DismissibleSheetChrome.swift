import SwiftUI

/// Shared chrome for modal settings and Direction sheets so users are never
/// trapped: always a Done control and Escape / cancelAction dismiss.
struct DismissibleSheetChrome<Content: View>: View {
    let title: String
    let doneTitle: String
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        doneTitle: String = "Done",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.doneTitle = doneTitle
        self.content = content
    }

    var body: some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(doneTitle) { dismiss() }
                            .keyboardShortcut(.cancelAction)
                            .accessibilityLabel(doneTitle)
                            .accessibilityHint("Closes this sheet and returns to the previous screen.")
                    }
                }
        }
        // AppKit exit command (Escape) when focus is inside the sheet.
        .onExitCommand { dismiss() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). Press Escape or \(doneTitle) to close.")
    }
}
