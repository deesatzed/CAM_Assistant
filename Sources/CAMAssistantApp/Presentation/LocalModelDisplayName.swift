import Foundation

/// Turns raw local model IDs into shorter labels for ordinary Settings.
enum LocalModelDisplayName {
    static func friendly(_ modelID: String) -> String {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown model" }

        var name = trimmed
        if let slash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: slash)...])
        }
        // Drop common quant/suffix noise for scanning, keep original in help.
        let dropSuffixes = [
            "-Instruct-4bit", "-instruct-4bit", "-GGUF", "-gguf",
            "-4bit", "-8bit", "-Q4_K_M", "-Q5_K_M", "-Q8_0",
        ]
        for suffix in dropSuffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        if name.count > 48 {
            return String(name.prefix(45)) + "…"
        }
        return name.isEmpty ? trimmed : name
    }
}
