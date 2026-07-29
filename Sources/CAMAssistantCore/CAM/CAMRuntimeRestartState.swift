import Foundation

public struct CAMRuntimeRestartState: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let pin: CAMVerifiedRuntimePin
    public let latestReceipt: CAMRuntimeProbeReceipt?
    public let updatedAt: Date

    public init(
        schemaVersion: Int = 1,
        pin: CAMVerifiedRuntimePin,
        latestReceipt: CAMRuntimeProbeReceipt?,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.pin = pin
        self.latestReceipt = latestReceipt
        self.updatedAt = updatedAt
    }
}

public enum CAMRuntimeRestartStateError: Error, Equatable {
    case invalidState
    case unsupportedSchema
    case receiptBindingMismatch
}

public struct CAMRuntimeRestartStateStore: Sendable {
    public static let fileName = "cam-runtime-history.json"

    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> CAMRuntimeRestartState? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let state: CAMRuntimeRestartState
        do {
            state = try JSONDecoder().decode(
                CAMRuntimeRestartState.self,
                from: Data(contentsOf: url)
            )
        } catch {
            throw CAMRuntimeRestartStateError.invalidState
        }
        return try Self.validated(state)
    }

    public func save(
        pin: CAMVerifiedRuntimePin,
        updatedAt: Date = Date()
    ) throws {
        let validatedPin = try Self.validated(pin)
        try write(
            CAMRuntimeRestartState(
                pin: validatedPin,
                latestReceipt: nil,
                updatedAt: updatedAt
            )
        )
    }

    public func save(
        receipt: CAMRuntimeProbeReceipt,
        for pin: CAMVerifiedRuntimePin,
        updatedAt: Date = Date()
    ) throws {
        let validatedPin = try Self.validated(pin)
        guard try load()?.pin.identitySHA256
                == validatedPin.identitySHA256 else {
            throw CAMRuntimeRestartStateError.receiptBindingMismatch
        }
        try Self.validate(receipt, for: validatedPin)
        try write(
            CAMRuntimeRestartState(
                pin: validatedPin,
                latestReceipt: receipt,
                updatedAt: updatedAt
            )
        )
    }

    private func write(_ state: CAMRuntimeRestartState) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            try encoder.encode(state).write(to: url, options: .atomic)
        } catch let error as CAMRuntimeRestartStateError {
            throw error
        } catch {
            throw CAMRuntimeRestartStateError.invalidState
        }
    }

    private static func validated(
        _ state: CAMRuntimeRestartState
    ) throws -> CAMRuntimeRestartState {
        guard state.schemaVersion == 1 else {
            throw CAMRuntimeRestartStateError.unsupportedSchema
        }
        let pin = try validated(state.pin)
        if let receipt = state.latestReceipt {
            try validate(receipt, for: pin)
        }
        return CAMRuntimeRestartState(
            schemaVersion: state.schemaVersion,
            pin: pin,
            latestReceipt: state.latestReceipt,
            updatedAt: state.updatedAt
        )
    }

    private static func validated(
        _ pin: CAMVerifiedRuntimePin
    ) throws -> CAMVerifiedRuntimePin {
        do {
            return try CAMVerifiedRuntimePin.decode(
                JSONEncoder().encode(pin)
            )
        } catch {
            throw CAMRuntimeRestartStateError.invalidState
        }
    }

    private static func validate(
        _ receipt: CAMRuntimeProbeReceipt,
        for pin: CAMVerifiedRuntimePin
    ) throws {
        let terminalShapeIsValid: Bool
        switch receipt.status {
        case .verified:
            terminalShapeIsValid =
                receipt.failureCode == nil
                && receipt.statistics != nil
                && !receipt.workspaceRetained
        case .failed, .timedOut, .cancelled, .outputLimited, .drifted:
            terminalShapeIsValid =
                receipt.failureCode != nil
                && receipt.statistics == nil
        }
        let digests = [
            receipt.donorDatabaseSHA256Before,
            receipt.donorDatabaseSHA256After,
            receipt.disposableDatabaseSHA256Before,
            receipt.disposableDatabaseSHA256After,
            receipt.outputSHA256,
            receipt.stderrSHA256,
        ].compactMap { $0 }
        guard receipt.schemaVersion == 2,
              receipt.toolID == "cam.stats.snapshot.v1",
              receipt.runtimeIdentitySHA256 == pin.identitySHA256,
              terminalShapeIsValid,
              digests.allSatisfy(isSHA256),
              receipt.outputByteCount >= 0,
              receipt.stderrByteCount >= 0,
              receipt.workspaceURL.isFileURL,
              receipt.finishedAt >= receipt.startedAt else {
            throw CAMRuntimeRestartStateError.receiptBindingMismatch
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value)
                || (97...102).contains(scalar.value)
        }
    }
}
