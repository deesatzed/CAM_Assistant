import CAMAssistantCore
import Foundation

func runCAMCommand(arguments: [String]) async -> Int32 {
    guard arguments.count >= 2 else {
        return camUsage()
    }
    do {
        switch arguments[1] {
        case "runtime-inspect":
            guard arguments.count == 6 || arguments.count == 8 else {
                return camUsage()
            }
            var timeout = 300.0
            if arguments.count == 8 {
                guard arguments[6] == "--timeout-seconds",
                      let supplied = Double(arguments[7]) else {
                    return camUsage()
                }
                timeout = supplied
            }
            let pin = try await CAMRuntimeInspector().inspectBounded(
                executableURL: URL(filePath: arguments[2]),
                configurationURL: URL(filePath: arguments[3]),
                databaseURL: URL(filePath: arguments[4]),
                timeoutSeconds: timeout
            )
            let outputURL = URL(filePath: arguments[5])
            try writeCAMJSON(pin, to: outputURL)
            print(
                "CAM runtime pin written: \(outputURL.path) "
                    + "identity=\(pin.identitySHA256)"
            )
            return 0
        case "runtime-probe":
            guard arguments.count == 5 || arguments.count == 7 else {
                return camUsage()
            }
            var timeout = 300.0
            if arguments.count == 7 {
                guard arguments[5] == "--timeout-seconds",
                      let supplied = Double(arguments[6]) else {
                    return camUsage()
                }
                timeout = supplied
            }
            let pin = try CAMVerifiedRuntimePin.decode(
                Data(contentsOf: URL(filePath: arguments[2]))
            )
            let receipt = await CAMDisposableStatisticsProbe().attempt(
                pin: pin,
                workspaceRoot: URL(filePath: arguments[3]),
                timeoutSeconds: timeout
            )
            let outputURL = URL(filePath: arguments[4])
            try writeCAMJSON(receipt, to: outputURL)
            if let statistics = receipt.statistics,
               receipt.status == .verified {
                print(
                    "CAM disposable statistics verified: "
                        + "methodologies=\(statistics.methodologyCount) "
                        + "repositories=\(statistics.sourceRepositoryCount) "
                        + "receipt=\(outputURL.path)"
                )
                return 0
            }
            FileHandle.standardError.write(
                Data(
                    "CAM disposable statistics \(receipt.status.rawValue): "
                        .appending(receipt.failureCode ?? "unknown_failure")
                        .appending(" receipt=\(outputURL.path)\n")
                        .utf8
                )
            )
            return 1
        case "runtime-execute-stats":
            guard arguments.count == 6
                || arguments.count == 8
                || arguments.count == 10 else {
                return camUsage()
            }
            var timeout = 60.0
            var maximumAttempts = 1
            var index = 6
            while index < arguments.count {
                guard index + 1 < arguments.count else {
                    return camUsage()
                }
                switch arguments[index] {
                case "--timeout-seconds":
                    guard let supplied = Double(arguments[index + 1]) else {
                        return camUsage()
                    }
                    timeout = supplied
                case "--maximum-attempts":
                    guard let supplied = Int(arguments[index + 1]) else {
                        return camUsage()
                    }
                    maximumAttempts = supplied
                default:
                    return camUsage()
                }
                index += 2
            }
            let pin = try CAMVerifiedRuntimePin.decode(
                Data(contentsOf: URL(filePath: arguments[2]))
            )
            let request = try CAMClosedToolRequest(
                toolID: .statistics,
                runtimeIdentitySHA256: pin.identitySHA256,
                idempotencyKey: arguments[5],
                maximumAttempts: maximumAttempts,
                timeoutSeconds: timeout
            )
            let result = await CAMClosedToolExecutor().attempt(
                request: request,
                pin: pin,
                workspaceRoot: URL(filePath: arguments[3])
            )
            let outputURL = URL(filePath: arguments[4])
            try writeCAMJSON(result.receipt, to: outputURL)
            print(
                "CAM closed tool \(result.receipt.status.rawValue): "
                    + "tool=\(result.receipt.toolID.rawValue) "
                    + "attempts=\(result.receipt.attemptCount) "
                    + "replayed=\(result.replayed) "
                    + "receipt=\(outputURL.path)"
            )
            return result.receipt.status == .verified ? 0 : 1
        default:
            return camUsage()
        }
    } catch {
        FileHandle.standardError.write(
            Data("CAM command failed: \(error)\n".utf8)
        )
        return 1
    }
}

private func writeCAMJSON<T: Encodable>(_ value: T, to outputURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try encoder.encode(value).write(to: outputURL, options: .atomic)
}

private func camUsage() -> Int32 {
    FileHandle.standardError.write(
        Data(
            """
            usage:
              cam-assistant cam runtime-inspect EXECUTABLE CONFIG DATABASE PIN_OUTPUT [--timeout-seconds N]
              cam-assistant cam runtime-probe PIN_INPUT WORKSPACE RECEIPT_OUTPUT [--timeout-seconds N]
              cam-assistant cam runtime-execute-stats PIN_INPUT WORKSPACE RECEIPT_OUTPUT IDEMPOTENCY_KEY [--timeout-seconds N] [--maximum-attempts N]
            """.appending("\n").utf8
        )
    )
    return 64
}
