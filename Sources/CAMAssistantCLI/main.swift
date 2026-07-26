import CAMAssistantCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "models" || arguments.first == "embeddings" {
    exit(runModelCommand(arguments: arguments))
} else if arguments.first == "orchestration-lock-probe" {
    exit(runOrchestrationLockProbe(arguments: arguments))
} else if arguments.first == "evaluate-retrieval" {
    guard arguments.count == 3 else {
        FileHandle.standardError.write(
            Data(
                "usage: cam-assistant evaluate-retrieval MANIFEST OUTPUT\n".utf8
            )
        )
        exit(64)
    }

    do {
        let manifestURL = URL(filePath: arguments[1])
        let outputURL = URL(filePath: arguments[2])
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appending(path: "cam-assistant-retrieval-evaluation")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let report = try RetrievalEvaluator().evaluate(
            manifestURL: manifestURL,
            indexURL: temporaryRoot.appending(path: "retrieval.sqlite")
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
        print(
            """
            Recall@10: \(report.recallAt10)
            MRR: \(report.meanReciprocalRank)
            cited-claim quote support: \(report.citedClaimQuoteSupport)
            latency p95 ms: \(report.latencyP95Milliseconds)
            benchmark: \(report.warmupRunsPerQuery) warm-up + \(report.measuredRunsPerQuery) measured runs per query
            report: \(outputURL.path)
            """
        )
    } catch {
        FileHandle.standardError.write(
            Data("retrieval evaluation failed: \(error)\n".utf8)
        )
        exit(1)
    }
} else {
    print("\(BuildIdentity.productName) (\(BuildIdentity.bundleIdentifier))")
}
