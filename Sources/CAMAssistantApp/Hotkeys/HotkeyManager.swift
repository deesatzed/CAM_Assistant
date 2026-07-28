import CAMAssistantCore
import AppKit
import Carbon
import Foundation

enum HotkeyAction: Sendable {
    case openAssistant
    case captureClipboard
}

enum AssistantHotkeyDefaults {
    static let openKey = "k"
    static let captureKey = "c"
}

@MainActor
struct AssistantForegroundActivation {
    let prepare: @MainActor () -> Void
    let activate: @MainActor () -> Void
    let raiseWindow: @MainActor () -> Void

    func perform() {
        prepare()
        activate()
        raiseWindow()
    }

    static let live = Self(
        prepare: {
            _ = NSApplication.shared.setActivationPolicy(.regular)
        },
        activate: {
            _ = NSRunningApplication.current.activate(
                options: [.activateAllWindows]
            )
            NSApplication.shared.activate(ignoringOtherApps: true)
        },
        raiseWindow: {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    )
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

    static func keyCode(for key: String) -> UInt32? {
        switch key {
        case "space": return UInt32(kVK_Space)
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return nil
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
