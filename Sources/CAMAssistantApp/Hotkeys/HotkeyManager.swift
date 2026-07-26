import CAMAssistantCore
import Carbon
import Foundation

enum HotkeyAction: Sendable {
    case openAssistant
    case captureClipboard
}

final class HotkeyManager {
    private var handler: EventHandlerRef?
    private var registered: [EventHotKeyRef] = []
    private var box: Unmanaged<HotkeyHandlerBox>?

    deinit { unregister() }

    func register(
        configuration: HotkeyConfiguration,
        action: @escaping @MainActor @Sendable (HotkeyAction) -> Void
    ) throws {
        unregister()
        let box = Unmanaged.passRetained(HotkeyHandlerBox(action: action))
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installResult = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            box.toOpaque(),
            &handler
        )
        guard installResult == noErr else {
            box.release()
            throw HotkeyManagerError.installFailed(installResult)
        }
        self.box = box
        do {
            try register(configuration.openAssistant, identifier: 1)
            try register(configuration.captureClipboard, identifier: 2)
        } catch {
            unregister()
            throw error
        }
    }

    func unregister() {
        registered.forEach { UnregisterEventHotKey($0) }
        registered = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        box?.release()
        box = nil
    }

    private func register(_ shortcut: HotkeyShortcut, identifier: UInt32) throws {
        guard let keyCode = Self.keyCode(for: shortcut.key) else {
            throw HotkeyManagerError.unsupportedKey(shortcut.key)
        }
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x43414D41), id: identifier)
        let result = RegisterEventHotKey(
            keyCode,
            Self.modifierFlags(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard result == noErr, let reference else {
            throw HotkeyManagerError.registrationFailed(result)
        }
        registered.append(reference)
    }

    private static func modifierFlags(for modifiers: Set<HotkeyModifier>) -> UInt32 {
        modifiers.reduce(0) { result, modifier in
            let flag: UInt32
            switch modifier {
            case .command: flag = UInt32(cmdKey)
            case .option: flag = UInt32(optionKey)
            case .shift: flag = UInt32(shiftKey)
            case .control: flag = UInt32(controlKey)
            }
            return result | flag
        }
    }

    private static func keyCode(for key: String) -> UInt32? {
        switch key {
        case "space": return UInt32(kVK_Space)
        default:
            guard key.count == 1, let scalar = key.unicodeScalars.first,
                  scalar.value >= 97, scalar.value <= 122 else { return nil }
            return UInt32(kVK_ANSI_A) + scalar.value - 97
        }
    }
}

enum HotkeyManagerError: Error, Equatable {
    case installFailed(OSStatus)
    case registrationFailed(OSStatus)
    case unsupportedKey(String)
}

private final class HotkeyHandlerBox: @unchecked Sendable {
    let action: @MainActor @Sendable (HotkeyAction) -> Void
    init(action: @escaping @MainActor @Sendable (HotkeyAction) -> Void) { self.action = action }
}

private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let box = Unmanaged<HotkeyHandlerBox>.fromOpaque(userData).takeUnretainedValue()
    let action: HotkeyAction = hotKeyID.id == 1 ? .openAssistant : .captureClipboard
    DispatchQueue.main.async { box.action(action) }
    return noErr
}
