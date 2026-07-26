import Foundation

public enum HotkeyModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case option
    case shift
    case control
}

public struct HotkeyShortcut: Codable, Equatable, Hashable, Sendable {
    public let key: String
    public let modifiers: Set<HotkeyModifier>

    public init(key: String, modifiers: Set<HotkeyModifier>) {
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.modifiers = modifiers
    }
}

public struct HotkeyConfiguration: Codable, Equatable, Sendable {
    public let openAssistant: HotkeyShortcut
    public let captureClipboard: HotkeyShortcut

    public init(openAssistant: HotkeyShortcut, captureClipboard: HotkeyShortcut) throws {
        guard !openAssistant.key.isEmpty, !captureClipboard.key.isEmpty else {
            throw HotkeyConfigurationError.emptyShortcut
        }
        guard openAssistant != captureClipboard else {
            throw HotkeyConfigurationError.duplicateShortcut
        }
        self.openAssistant = openAssistant
        self.captureClipboard = captureClipboard
    }
}

public enum HotkeyConfigurationError: Error, Equatable {
    case emptyShortcut
    case duplicateShortcut
}

public final class HotkeyConfigurationStore {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func save(_ configuration: HotkeyConfiguration) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(configuration).write(to: url, options: .atomic)
    }

    public func load() throws -> HotkeyConfiguration? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(HotkeyConfiguration.self, from: Data(contentsOf: url))
    }
}

public enum GlobalHotkeyStatus: Equatable, Sendable {
    case unregistered
    case active
    case unavailable

    public var label: String {
        switch self {
        case .unregistered: "Global hotkeys not registered"
        case .active: "Global hotkeys active"
        case .unavailable: "Global hotkeys unavailable"
        }
    }

    public var hint: String {
        switch self {
        case .unregistered:
            "The app has not registered global shortcuts in this session."
        case .active:
            "Shortcuts are registered for this app session; keyboard action still requires an operating-system event."
        case .unavailable:
            "The operating system rejected shortcut registration; use the visible local controls instead."
        }
    }
}

public struct AccessibilityStatus: Equatable, Sendable {
    public let label: String
    public let hint: String

    public init(health: AppHealth) {
        label = health.statusMessage.lowercased()
        hint = "Capture and local search remain available without a network connection."
    }
}
