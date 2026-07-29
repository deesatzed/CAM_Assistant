import Foundation

public enum ResearchAcquisitionCommand: Equatable, Sendable {
    case acquireExactApproved(
        vaultRoot: URL,
        runID: String,
        query: String,
        target: URL
    )

    public static func parse(arguments: [String]) throws -> Self {
        guard arguments.count == 7,
              arguments[0] == "research",
              arguments[1] == "acquire",
              arguments[2] == "--approve-exact",
              arguments[3].hasPrefix("/"),
              !arguments[4].trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              !arguments[5].trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              let target = URL(string: arguments[6]),
              let canonicalTarget = try? PublicResearchURLPolicy()
                  .validate(target),
              canonicalTarget == target else {
            throw ResearchAcquisitionCommandError.invalidArguments
        }
        return .acquireExactApproved(
            vaultRoot: URL(filePath: arguments[3]).standardizedFileURL,
            runID: arguments[4],
            query: arguments[5],
            target: canonicalTarget
        )
    }
}

public enum ResearchAcquisitionCommandError: Error, Equatable {
    case invalidArguments
}

public struct ResearchAcquisitionCommandExecutor: Sendable {
    public typealias Operation = @Sendable (
        _ command: ResearchAcquisitionCommand
    ) async throws -> ResearchAcquisitionResult

    private let operation: Operation

    public init() {
        operation = Self.liveOperation
    }

    public init(operation: @escaping Operation) {
        self.operation = operation
    }

    public func execute(
        _ command: ResearchAcquisitionCommand
    ) async throws -> String {
        let result = try await operation(command)
        let receipt = result.receipt
        let signals = receipt.safetySignals.isEmpty
            ? "none"
            : receipt.safetySignals.map(\.rawValue).joined(separator: ",")
        return """
        research acquisition: pass
        job id: \(result.job.id.uuidString.lowercased())
        status: \(result.job.status.rawValue)
        requested url: \(receipt.requestedURL)
        final url: \(receipt.finalURL)
        content type: \(receipt.contentType)
        bytes: \(receipt.byteCount)
        sha256: \(receipt.sha256)
        route: \(receipt.route)
        tool: \(receipt.toolID)
        maximum cost usd: \(receipt.maximumCostUSD)
        actual cost usd: \(receipt.actualCostUSD)
        duplicate source: \(receipt.wasDuplicateSource)
        source quality: \(receipt.quality.kind.rawValue)
        source reviewed: \(receipt.quality.reviewed)
        untrusted content signals: \(signals)
        packet retention: \(result.packet.retention.rawValue)
        """
    }

    private static func liveOperation(
        _ command: ResearchAcquisitionCommand
    ) async throws -> ResearchAcquisitionResult {
        switch command {
        case let .acquireExactApproved(vaultRoot, runID, query, target):
            let coordinator = try ResearchAcquisitionCoordinator.live(
                vaultRoot: vaultRoot
            )
            let proposal = try coordinator.proposal(
                runID: runID,
                query: query,
                target: target,
                stateVersion: 0,
                expiresAt: Date().addingTimeInterval(600)
            )
            return try await coordinator.execute(
                proposal,
                approvalSource: "cli-user-explicit-approve-exact"
            )
        }
    }
}
