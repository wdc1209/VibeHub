import AppKit
import Foundation

enum ShortcutAction: String {
    case send
    case voice
    case previousTarget
    case nextTarget
    case previousWindow
    case nextWindow
}

struct ShortcutDescriptor: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    var storageValue: String {
        let ordered: [(NSEvent.ModifierFlags, String)] = [
            (.control, "control"),
            (.command, "command"),
            (.option, "option"),
            (.shift, "shift")
        ]
        let parts = ordered.compactMap { modifiers.contains($0.0) ? $0.1 : nil } + [key]
        return parts.joined(separator: "+")
    }

    var displayLabel: String {
        let ordered: [(NSEvent.ModifierFlags, String)] = [
            (.control, "Control"),
            (.command, "Command"),
            (.option, "Option"),
            (.shift, "Shift")
        ]
        let parts = ordered.compactMap { modifiers.contains($0.0) ? $0.1 : nil } + [displayKeyLabel]
        return parts.joined(separator: " + ")
    }

    private var displayKeyLabel: String {
        switch key {
        case "enter":
            return "Enter"
        case "return":
            return "Return"
        case "space":
            return "Space"
        case "left":
            return "Left"
        case "right":
            return "Right"
        case "up":
            return "Up"
        case "down":
            return "Down"
        default:
            return key.uppercased()
        }
    }
}

@MainActor
final class ShortcutSettingsStore: ObservableObject {
    static let shared = ShortcutSettingsStore()

    @Published var sendShortcutInput: String
    @Published var voiceShortcutInput: String
    @Published var previousTargetShortcutInput: String
    @Published var nextTargetShortcutInput: String
    @Published var previousWindowShortcutInput: String
    @Published var nextWindowShortcutInput: String

    private let defaults = UserDefaults.standard
    private let sendKey = "tokenCard.sendShortcut"
    private let voiceKey = "tokenCard.voiceShortcut"
    private let previousTargetKey = "tokenCard.previousTargetShortcut"
    private let nextTargetKey = "tokenCard.nextTargetShortcut"
    private let previousWindowKey = "tokenCard.previousWindowShortcut"
    private let nextWindowKey = "tokenCard.nextWindowShortcut"

    private let defaultSend = ShortcutDescriptor(key: "enter", modifiers: [.control])
    private let defaultVoice = ShortcutDescriptor(key: "m", modifiers: [.control])
    private let defaultPreviousTarget = ShortcutDescriptor(key: "up", modifiers: [])
    private let defaultNextTarget = ShortcutDescriptor(key: "down", modifiers: [])
    private let defaultPreviousWindow = ShortcutDescriptor(key: "left", modifiers: [])
    private let defaultNextWindow = ShortcutDescriptor(key: "right", modifiers: [])
    private let legacyPreviousTarget = ShortcutDescriptor(key: "up", modifiers: [.shift])
    private let legacyNextTarget = ShortcutDescriptor(key: "down", modifiers: [.shift])
    private let legacyPreviousWindow = ShortcutDescriptor(key: "left", modifiers: [.shift])
    private let legacyNextWindow = ShortcutDescriptor(key: "right", modifiers: [.shift])

    private init() {
        let storedSend = defaults.string(forKey: sendKey) ?? defaultSend.storageValue
        let storedVoice = defaults.string(forKey: voiceKey) ?? defaultVoice.storageValue
        let storedPreviousTarget = Self.migrateLegacyShortcut(
            defaults: defaults,
            key: previousTargetKey,
            stored: defaults.string(forKey: previousTargetKey),
            legacy: legacyPreviousTarget,
            fallback: defaultPreviousTarget
        )
        let storedNextTarget = Self.migrateLegacyShortcut(
            defaults: defaults,
            key: nextTargetKey,
            stored: defaults.string(forKey: nextTargetKey),
            legacy: legacyNextTarget,
            fallback: defaultNextTarget
        )
        let storedPreviousWindow = Self.migrateLegacyShortcut(
            defaults: defaults,
            key: previousWindowKey,
            stored: defaults.string(forKey: previousWindowKey),
            legacy: legacyPreviousWindow,
            fallback: defaultPreviousWindow
        )
        let storedNextWindow = Self.migrateLegacyShortcut(
            defaults: defaults,
            key: nextWindowKey,
            stored: defaults.string(forKey: nextWindowKey),
            legacy: legacyNextWindow,
            fallback: defaultNextWindow
        )
        sendShortcutInput = storedSend
        voiceShortcutInput = storedVoice
        previousTargetShortcutInput = storedPreviousTarget
        nextTargetShortcutInput = storedNextTarget
        previousWindowShortcutInput = storedPreviousWindow
        nextWindowShortcutInput = storedNextWindow
    }

    private static func migrateLegacyShortcut(
        defaults: UserDefaults,
        key: String,
        stored: String?,
        legacy: ShortcutDescriptor,
        fallback: ShortcutDescriptor
    ) -> String {
        guard let stored else { return fallback.storageValue }
        if stored == legacy.storageValue {
            defaults.set(fallback.storageValue, forKey: key)
            return fallback.storageValue
        }
        return stored
    }

    var sendShortcut: ShortcutDescriptor { Self.parse(sendShortcutInput) ?? defaultSend }
    var voiceShortcut: ShortcutDescriptor { Self.parse(voiceShortcutInput) ?? defaultVoice }
    var previousTargetShortcut: ShortcutDescriptor { Self.parse(previousTargetShortcutInput) ?? defaultPreviousTarget }
    var nextTargetShortcut: ShortcutDescriptor { Self.parse(nextTargetShortcutInput) ?? defaultNextTarget }
    var previousWindowShortcut: ShortcutDescriptor { Self.parse(previousWindowShortcutInput) ?? defaultPreviousWindow }
    var nextWindowShortcut: ShortcutDescriptor { Self.parse(nextWindowShortcutInput) ?? defaultNextWindow }
    var sendShortcutLabel: String { sendShortcut.displayLabel }
    var voiceShortcutLabel: String { voiceShortcut.displayLabel }
    var previousTargetShortcutLabel: String { previousTargetShortcut.displayLabel }
    var nextTargetShortcutLabel: String { nextTargetShortcut.displayLabel }
    var previousWindowShortcutLabel: String { previousWindowShortcut.displayLabel }
    var nextWindowShortcutLabel: String { nextWindowShortcut.displayLabel }
    var sendShortcutError: String? { Self.validationError(for: sendShortcutInput) }
    var voiceShortcutError: String? { Self.validationError(for: voiceShortcutInput) }
    var previousTargetShortcutError: String? { Self.validationError(for: previousTargetShortcutInput) }
    var nextTargetShortcutError: String? { Self.validationError(for: nextTargetShortcutInput) }
    var previousWindowShortcutError: String? { Self.validationError(for: previousWindowShortcutInput) }
    var nextWindowShortcutError: String? { Self.validationError(for: nextWindowShortcutInput) }

    func saveSendShortcut() {
        let descriptor = Self.parse(sendShortcutInput) ?? defaultSend
        sendShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: sendKey)
    }

    func saveVoiceShortcut() {
        let descriptor = Self.parse(voiceShortcutInput) ?? defaultVoice
        voiceShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: voiceKey)
    }

    func savePreviousTargetShortcut() {
        let descriptor = Self.parse(previousTargetShortcutInput) ?? defaultPreviousTarget
        previousTargetShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: previousTargetKey)
    }

    func saveNextTargetShortcut() {
        let descriptor = Self.parse(nextTargetShortcutInput) ?? defaultNextTarget
        nextTargetShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: nextTargetKey)
    }

    func savePreviousWindowShortcut() {
        let descriptor = Self.parse(previousWindowShortcutInput) ?? defaultPreviousWindow
        previousWindowShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: previousWindowKey)
    }

    func saveNextWindowShortcut() {
        let descriptor = Self.parse(nextWindowShortcutInput) ?? defaultNextWindow
        nextWindowShortcutInput = descriptor.storageValue
        defaults.set(descriptor.storageValue, forKey: nextWindowKey)
    }

    func matches(_ event: NSEvent, action: ShortcutAction) -> Bool {
        let descriptor = descriptor(for: action)
        let eventKey = Self.eventKey(for: event)
        let eventModifiers = normalizedModifiers(event.modifierFlags)
        return event.type == .keyDown && eventKey == descriptor.key && eventModifiers == descriptor.modifiers
    }

    func shouldFinishVoice(for event: NSEvent) -> Bool {
        let descriptor = voiceShortcut
        if event.type == .keyUp {
            return Self.eventKey(for: event) == descriptor.key
        }

        if event.type == .flagsChanged {
            let eventModifiers = normalizedModifiers(event.modifierFlags)
            return !eventModifiers.isSuperset(of: descriptor.modifiers)
        }

        return false
    }

    private func descriptor(for action: ShortcutAction) -> ShortcutDescriptor {
        switch action {
        case .send:
            return sendShortcut
        case .voice:
            return voiceShortcut
        case .previousTarget:
            return previousTargetShortcut
        case .nextTarget:
            return nextTargetShortcut
        case .previousWindow:
            return previousWindowShortcut
        case .nextWindow:
            return nextWindowShortcut
        }
    }

    private func normalizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.control, .command, .option, .shift])
    }

    static func validationError(for raw: String) -> String? {
        parse(raw) == nil ? "格式示例：control+enter、shift+up、shift+left" : nil
    }

    static func parse(_ raw: String) -> ShortcutDescriptor? {
        let normalized = raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "⌃", with: "control+")
            .replacingOccurrences(of: "⌘", with: "command+")
            .replacingOccurrences(of: "⌥", with: "option+")
            .replacingOccurrences(of: "⇧", with: "shift+")

        let parts = normalized.split(separator: "+").map(String.init).filter { !$0.isEmpty }
        guard let keyToken = parts.last else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        for token in parts.dropLast() {
            switch token {
            case "control", "ctrl":
                modifiers.insert(.control)
            case "command", "cmd":
                modifiers.insert(.command)
            case "option", "opt", "alt":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            default:
                return nil
            }
        }

        let resolvedKey: String
        switch keyToken {
        case "enter", "return":
            resolvedKey = "enter"
        case "space", "spacebar":
            resolvedKey = "space"
        case "left", "arrowleft":
            resolvedKey = "left"
        case "right", "arrowright":
            resolvedKey = "right"
        case "up", "arrowup":
            resolvedKey = "up"
        case "down", "arrowdown":
            resolvedKey = "down"
        default:
            guard keyToken.count == 1, keyToken.first?.isLetter == true else { return nil }
            resolvedKey = keyToken
        }

        return ShortcutDescriptor(key: resolvedKey, modifiers: modifiers)
    }

    static func eventKey(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36, 76:
            return "enter"
        case 49:
            return "space"
        case 123:
            return "left"
        case 124:
            return "right"
        case 125:
            return "down"
        case 126:
            return "up"
        default:
            let characters = (event.charactersIgnoringModifiers ?? "").lowercased()
            return String(characters.prefix(1))
        }
    }
}
