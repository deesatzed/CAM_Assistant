import CAMAssistantCore
import SwiftUI

@main
struct CAMAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            Text(BuildIdentity.productName)
                .frame(minWidth: 420, minHeight: 280)
        }
    }
}
