import CAMAssistantCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "vault" {
    exit(runVaultCommand(arguments: arguments))
} else if arguments.first == "cam" {
    exit(await runCAMCommand(arguments: arguments))
} else if arguments.first == "research" {
    exit(await runResearchCommand(arguments: arguments))
} else if arguments.first == "models" || arguments.first == "embeddings" {
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
} else if arguments.first == "evaluate-repository-semantic-v3" {
    do {
        let request = try RepositorySemanticV3EvaluationRequest.parse(
            arguments: arguments
        )
        let generator = try RepositorySemanticV3LocalGenerator(
            assignment: request.assignment
        )
        _ = try await generator.health()
        let report = try await RepositorySemanticV3Evaluator().evaluate(
            manifestURL: request.manifestURL,
            generator: generator
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: request.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(
            to: request.outputURL,
            options: .atomic
        )
        print(
            """
            repository semantic v3 claim recall: \(report.claimRecall)
            claim precision: \(report.claimPrecision)
            evidence precision: \(report.evidencePrecision)
            counterevidence recall: \(report.counterevidenceRecall)
            abstention accuracy: \(report.abstentionAccuracy)
            frozen gates: \(report.meetsFrozenThresholds ? "pass" : "fail")
            report: \(request.outputURL.path)
            """
        )
        let exitCode = RepositorySemanticV3EvaluationExitCode.forReport(
            report
        )
        if exitCode != 0 {
            exit(exitCode)
        }
    } catch RepositorySemanticV3EvaluationRequestError
        .invalidArguments {
        FileHandle.standardError.write(
            Data(
                """
                usage: cam-assistant evaluate-repository-semantic-v3 MANIFEST OUTPUT MODEL LOOPBACK_ENDPOINT
                """.appending("\n").utf8
            )
        )
        exit(64)
    } catch {
        FileHandle.standardError.write(
            Data(
                "repository semantic v3 evaluation failed: \(error)\n"
                    .utf8
            )
        )
        exit(1)
    }
} else if arguments.first == "evaluate-repository-semantic" {
    do {
        let request = try RepositorySemanticEvaluationRequest.parse(
            arguments: arguments
        )
        let generator = try RepositorySemanticLocalGenerator(
            assignment: request.assignment
        )
        _ = try await generator.health()
        let report = try await RepositorySemanticEvaluator().evaluate(
            manifestURL: request.manifestURL,
            generator: generator
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: request.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(
            to: request.outputURL,
            options: .atomic
        )
        print(
            """
            repository semantic observation recall: \(report.observationRecall)
            evidence precision: \(report.evidencePrecision)
            counterevidence recall: \(report.counterevidenceRecall)
            abstention accuracy: \(report.abstentionAccuracy)
            frozen gates: \(report.meetsFrozenThresholds ? "pass" : "fail")
            report: \(request.outputURL.path)
            """
        )
        let exitCode = RepositorySemanticEvaluationExitCode.forReport(report)
        if exitCode != 0 {
            exit(exitCode)
        }
    } catch RepositorySemanticEvaluationRequestError.invalidArguments {
        FileHandle.standardError.write(
            Data(
                """
                usage: cam-assistant evaluate-repository-semantic MANIFEST OUTPUT MODEL LOOPBACK_ENDPOINT
                """.appending("\n").utf8
            )
        )
        exit(64)
    } catch {
        FileHandle.standardError.write(
            Data(
                "repository semantic evaluation failed: \(error)\n".utf8
            )
        )
        exit(1)
    }
} else if arguments.first == "evaluate-generated" {
    do {
        let request = try GeneratedAnswerEvaluationRequest.parse(
            arguments: arguments
        )
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appending(path: "cam-assistant-generated-evaluation")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let report = try await GeneratedAnswerEvaluator().evaluate(
            manifestURL: request.manifestURL,
            indexURL: temporaryRoot.appending(path: "evaluation.sqlite"),
            assignment: request.assignment,
            benchmark: request.benchmark
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: request.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(
            to: request.outputURL,
            options: .atomic
        )
        print(
            """
            generated cited-claim support: \(report.citedClaimSupport)
            abstention accuracy: \(report.abstentionAccuracy)
            warm end-to-end p95 ms: \(report.warmEndToEndP95Milliseconds)
            frozen gates: \(report.meetsFrozenThresholds ? "pass" : "fail")
            report: \(request.outputURL.path)
            """
        )
        let exitCode = GeneratedAnswerEvaluationExitCode.forReport(report)
        if exitCode != 0 {
            exit(exitCode)
        }
    } catch GeneratedAnswerEvaluationRequestError.invalidArguments {
        FileHandle.standardError.write(
            Data(
                """
                usage: cam-assistant evaluate-generated MANIFEST OUTPUT MODEL LOOPBACK_ENDPOINT [--warmup N] [--measured N]
                """.appending("\n").utf8
            )
        )
        exit(64)
    } catch {
        FileHandle.standardError.write(
            Data("generated-answer evaluation failed: \(error)\n".utf8)
        )
        exit(1)
    }
} else {
    print("\(BuildIdentity.productName) (\(BuildIdentity.bundleIdentifier))")
}
