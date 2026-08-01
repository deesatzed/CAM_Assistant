import Foundation
import Testing
@testable import CAMAssistantCore

@Test("Meaning Preview v1 fixture is complete valid and frozen")
func meaningPreviewFixtureIsCompleteValidAndFrozen() throws {
    let data = try Data(contentsOf: meaningPreviewFixtureURL())
    let manifest = try MeaningPreviewEvaluationManifest.decode(data)

    try manifest.validate()

    #expect(manifest.manifestVersion == 1)
    #expect(manifest.cases.count == 22)
    #expect(manifest.cases.filter { $0.expectedDecision == .surface }.count == 7)
    #expect(manifest.cases.filter { $0.expectedDecision == .silence }.count == 15)
    #expect(Set(manifest.cases.flatMap(\.coverage)) == MeaningPreviewEvaluationManifest.requiredCoverage)
    #expect(manifest.thresholds == .init(
        decisionAccuracy: 1,
        supportRecall: 1,
        evidencePrecision: 1,
        counterevidenceRecall: 1,
        abstentionAccuracy: 1,
        prohibitedBehaviorAccuracy: 1
    ))
    #expect(
        MeaningPreviewEvaluationManifest.sha256(of: data)
            == "62cfed6293462f94103752e1d3855158675f479b5ae6cf7926ed20e4726cabfd"
    )
}

@Test("Meaning Preview manifest rejects unknown schema fields")
func meaningPreviewManifestRejectsUnknownFields() throws {
    let data = try Data(contentsOf: meaningPreviewFixtureURL())
    var object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    object["unexpected"] = true
    let modified = try JSONSerialization.data(withJSONObject: object)

    #expect(
        throws: MeaningPreviewEvaluationManifestError.unexpectedKeys(
            path: "$",
            keys: ["unexpected"]
        )
    ) {
        _ = try MeaningPreviewEvaluationManifest.decode(modified)
    }
}

@Test("Meaning Preview manifest rejects nested unknown and missing fields")
func meaningPreviewManifestRejectsNestedSchemaDrift() throws {
    let data = try Data(contentsOf: meaningPreviewFixtureURL())
    var root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    var cases = try #require(root["cases"] as? [[String: Any]])
    cases[0]["unexpected"] = true
    root["cases"] = cases
    let unknown = try JSONSerialization.data(withJSONObject: root)
    #expect(
        throws: MeaningPreviewEvaluationManifestError.unexpectedKeys(
            path: "$.cases[0]",
            keys: ["unexpected"]
        )
    ) {
        _ = try MeaningPreviewEvaluationManifest.decode(unknown)
    }

    root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    cases = try #require(root["cases"] as? [[String: Any]])
    var evidence = try #require(cases[0]["evidence"] as? [[String: Any]])
    evidence[0].removeValue(forKey: "text")
    cases[0]["evidence"] = evidence
    root["cases"] = cases
    let missing = try JSONSerialization.data(withJSONObject: root)
    #expect(
        throws: MeaningPreviewEvaluationManifestError.missingKeys(
            path: "$.cases[0].evidence[0]",
            keys: ["text"]
        )
    ) {
        _ = try MeaningPreviewEvaluationManifest.decode(missing)
    }
}

@Test("deterministic expected replay passes every frozen Meaning Preview gate")
func deterministicMeaningPreviewReplayPassesFrozenGate() async throws {
    let evaluator = MeaningPreviewEvaluator()
    let first = try await evaluator.evaluateDeterministicReplay(
        manifestURL: meaningPreviewFixtureURL()
    )
    let second = try await evaluator.evaluateDeterministicReplay(
        manifestURL: meaningPreviewFixtureURL()
    )

    #expect(first == second)
    #expect(first.evaluatorVersion == "meaning-preview-evaluator-v1")
    #expect(first.evaluationMode == .deterministicReplay)
    #expect(first.runtimeIdentity == "deterministic-expected-replay-v1")
    #expect(first.modelID == "none")
    #expect(first.caseCount == 22)
    #expect(first.decisionAccuracy == 1)
    #expect(first.supportRecall == 1)
    #expect(first.evidencePrecision == 1)
    #expect(first.counterevidenceRecall == 1)
    #expect(first.abstentionAccuracy == 1)
    #expect(first.prohibitedBehaviorAccuracy == 1)
    #expect(first.failedCaseIDs.isEmpty)
    #expect(first.unansweredCaseIDs.isEmpty)
    #expect(first.prohibitedFindings.isEmpty)
    #expect(first.meetsFrozenThresholds)
    #expect(!first.namedModelEligible)
    #expect(MeaningPreviewEvaluationExitCode.forReport(first) == 0)
}

@Test("correct evidence IDs cannot hide meaningless surface prose")
func meaninglessMeaningPreviewSurfaceTextFailsGrounding() async throws {
    let manifest = try loadMeaningPreviewManifest()
    var candidates = expectedCandidates(for: manifest)
    let surface = try #require(
        manifest.cases.first(where: { $0.expectedDecision == .surface })
    )
    candidates[surface.id] = MeaningPreviewEvaluationCandidate(
        caseID: surface.id,
        decision: .surface,
        observation: "x",
        interpretation: "x",
        opening: "x",
        supportIDs: surface.requiredSupportIDs,
        counterevidenceIDs: surface.requiredCounterevidenceIDs,
        uncertainty: 0.5
    )

    let report = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: MeaningPreviewStaticCandidateSupplier(
            runtimeIdentity: "synthetic-grounding-probe",
            modelID: "synthetic-model",
            candidates: candidates
        )
    )

    #expect(!report.meetsFrozenThresholds)
    #expect(!report.namedModelEligible)
    #expect(report.failedCaseIDs.contains(surface.id))
    #expect(
        report.caseResults.first(where: { $0.caseID == surface.id })?.errorCode
            == "ungrounded_text"
    )
}

@Test("deterministic or missing model identity is never named-model eligible")
func noneModelCannotBecomeNamedModelEligible() async throws {
    let manifest = try loadMeaningPreviewManifest()
    let report = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: MeaningPreviewStaticCandidateSupplier(
            runtimeIdentity: "synthetic-runtime",
            modelID: "none",
            candidates: expectedCandidates(for: manifest)
        )
    )

    #expect(report.evaluationMode == .namedModel)
    #expect(report.meetsFrozenThresholds)
    #expect(!report.namedModelEligible)
    #expect(MeaningPreviewEvaluationExitCode.forReport(report) == 2)

    let eligible = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: MeaningPreviewStaticCandidateSupplier(
            runtimeIdentity: "selected-loopback-runtime",
            modelID: "frozen-local-model",
            candidates: expectedCandidates(for: manifest)
        )
    )
    #expect(eligible.namedModelEligible)
    #expect(MeaningPreviewEvaluationExitCode.forReport(eligible) == 0)
}

@Test("named suppliers receive only neutral unlabeled evaluation input")
func namedSupplierInputDoesNotLeakFrozenLabels() async throws {
    let manifest = try loadMeaningPreviewManifest()
    let supplier = RecordingMeaningPreviewSupplier(
        candidates: expectedCandidates(for: manifest)
    )
    _ = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: supplier
    )

    let inputs = await supplier.inputs
    #expect(inputs.count == manifest.cases.count)
    let encoded = try JSONEncoder().encode(inputs)
    let objects = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [[String: Any]]
    )
    #expect(objects.allSatisfy {
        Set($0.keys) == ["caseID", "domain", "prompt", "context", "evidence"]
    })
    let evidenceObjects = objects.flatMap {
        $0["evidence"] as? [[String: Any]] ?? []
    }
    #expect(evidenceObjects.allSatisfy { Set($0.keys) == ["id", "text"] })
    let encodedText = try #require(String(data: encoded, encoding: .utf8))
    #expect(!encodedText.contains("expectedDecision"))
    #expect(!encodedText.contains("referenceObservation"))
    #expect(!encodedText.contains("requiredSupportIDs"))
    #expect(!encodedText.contains("forbiddenBehaviorIDs"))
    #expect(!encodedText.contains("whyCorrect"))
    #expect(!encodedText.contains("pressureRisk"))
    #expect(!encodedText.contains("role"))
}

@Test("token salad and polarity reversal fail frozen grounding")
func tokenSaladAndPolarityReversalFailGrounding() async throws {
    let manifest = try loadMeaningPreviewManifest()
    let surface = try #require(
        manifest.cases.first(where: { $0.expectedDecision == .surface })
    )
    let invalidCandidates = [
        MeaningPreviewEvaluationCandidate(
            caseID: surface.id,
            decision: .surface,
            observation: "Thoughtful selected context.",
            interpretation: "may without appreciation",
            opening: "pause note if",
            supportIDs: surface.requiredSupportIDs,
            counterevidenceIDs: surface.requiredCounterevidenceIDs,
            uncertainty: 0.5
        ),
        MeaningPreviewEvaluationCandidate(
            caseID: surface.id,
            decision: .surface,
            observation: "A thoughtful note is not present in the selected context.",
            interpretation: surface.referenceInterpretation,
            opening: surface.referenceOpening,
            supportIDs: surface.requiredSupportIDs,
            counterevidenceIDs: surface.requiredCounterevidenceIDs,
            uncertainty: 0.5
        ),
        MeaningPreviewEvaluationCandidate(
            caseID: surface.id,
            decision: .surface,
            observation: surface.referenceObservation,
            interpretation: surface.referenceInterpretation,
            opening: "Pause with the note for one breath regardless of welcome.",
            supportIDs: surface.requiredSupportIDs,
            counterevidenceIDs: surface.requiredCounterevidenceIDs,
            uncertainty: 0.5
        ),
    ]

    for invalid in invalidCandidates {
        let report = try await MeaningPreviewEvaluator().evaluate(
            manifestURL: meaningPreviewFixtureURL(),
            supplier: MeaningPreviewStaticCandidateSupplier(
                runtimeIdentity: "grounding-adversary",
                modelID: "synthetic-model",
                candidates: replacingCandidate(
                    in: manifest,
                    caseID: surface.id,
                    candidate: invalid
                )
            )
        )
        #expect(
            report.caseResults.first(where: { $0.caseID == surface.id })?
                .errorCode == "ungrounded_text"
        )
        #expect(!report.namedModelEligible)
    }
}

@Test("evaluation reports never serialize candidate prose")
func meaningPreviewReportOmitsCandidateProse() async throws {
    let manifest = try loadMeaningPreviewManifest()
    let surface = try #require(
        manifest.cases.first(where: { $0.expectedDecision == .surface })
    )
    let marker = "UNIQUE_PRIVATE_CANDIDATE_MARKER_7F2A"
    let report = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: MeaningPreviewStaticCandidateSupplier(
            runtimeIdentity: "secrecy-probe",
            modelID: "synthetic-model",
            candidates: replacingCandidate(
                in: manifest,
                caseID: surface.id,
                candidate: MeaningPreviewEvaluationCandidate(
                    caseID: surface.id,
                    decision: .surface,
                    observation: marker,
                    interpretation: surface.referenceInterpretation,
                    opening: surface.referenceOpening,
                    supportIDs: surface.requiredSupportIDs,
                    counterevidenceIDs: surface.requiredCounterevidenceIDs,
                    uncertainty: 0.5
                )
            )
        )
    )
    let reportText = try #require(
        String(data: JSONEncoder().encode(report), encoding: .utf8)
    )
    #expect(!reportText.contains(marker))
}

@Test("case-scoped prohibitions catch exact and paraphrased behaviors")
func caseScopedProhibitionDetectionIsOperational() throws {
    let manifest = try loadMeaningPreviewManifest()
    for behavior in manifest.prohibitedBehaviors {
        let evaluationCase = try #require(
            manifest.cases.first {
                $0.forbiddenBehaviorIDs.contains(behavior.id)
            }
        )
        let findings = manifest.prohibitedFindings(
            in: [behavior.phrases[0]],
            caseID: evaluationCase.id
        )
        #expect(findings.contains(where: { $0.behaviorID == behavior.id }))
    }

    let paraphrases: [(String, String, String)] = [
        ("appreciation-without-homework", "pressure", "You have to act right away."),
        ("service-without-performance", "moral-score", "Delay would be a moral failing."),
        ("capacity-without-productivity", "diagnosis", "This shows you are clinically depressed."),
    ]
    for (caseID, behaviorID, prose) in paraphrases {
        let findings = manifest.prohibitedFindings(in: [prose], caseID: caseID)
        #expect(findings.contains(where: { $0.behaviorID == behaviorID }))
    }

    #expect(
        manifest.prohibitedFindings(
            in: ["This shows you are clinically depressed."],
            caseID: "appreciation-without-homework"
        ).isEmpty
    )
}

@Test("malformed candidates produce exact fail-closed error codes")
func malformedMeaningPreviewCandidatesHaveExactErrors() async throws {
    let manifest = try loadMeaningPreviewManifest()
    let surface = try #require(
        manifest.cases.first(where: { $0.expectedDecision == .surface })
    )
    let silence = try #require(
        manifest.cases.first(where: { $0.expectedDecision == .silence })
    )

    let probes: [(String, String, [String: MeaningPreviewEvaluationCandidate])] = [
        ("missing", surface.id, {
            var values = expectedCandidates(for: manifest)
            values.removeValue(forKey: surface.id)
            return values
        }()),
        ("identity", surface.id, replacingCandidate(
            in: manifest,
            caseID: surface.id,
            candidate: candidate(for: surface, caseID: "wrong-case")
        )),
        ("unknown", surface.id, replacingCandidate(
            in: manifest,
            caseID: surface.id,
            candidate: candidate(
                for: surface,
                supportIDs: surface.requiredSupportIDs + ["invented"]
            )
        )),
        ("duplicate", surface.id, replacingCandidate(
            in: manifest,
            caseID: surface.id,
            candidate: candidate(
                for: surface,
                supportIDs: surface.requiredSupportIDs
                    + [surface.requiredSupportIDs[0]]
            )
        )),
        ("silence-text", silence.id, replacingCandidate(
            in: manifest,
            caseID: silence.id,
            candidate: MeaningPreviewEvaluationCandidate(
                caseID: silence.id,
                decision: .silence,
                observation: "invented",
                interpretation: nil,
                opening: nil,
                supportIDs: [],
                counterevidenceIDs: [],
                uncertainty: nil
            )
        )),
        ("uncertainty", surface.id, replacingCandidate(
            in: manifest,
            caseID: surface.id,
            candidate: candidate(for: surface, uncertainty: 2)
        )),
    ]
    let expectedCodes = [
        "missing_candidate", "identity_mismatch", "unknown_evidence",
        "malformed_candidate", "malformed_candidate", "malformed_candidate",
    ]

    for (index, probe) in probes.enumerated() {
        let report = try await MeaningPreviewEvaluator().evaluate(
            manifestURL: meaningPreviewFixtureURL(),
            supplier: MeaningPreviewStaticCandidateSupplier(
                runtimeIdentity: "negative-\(probe.0)",
                modelID: "synthetic-model",
                candidates: probe.2
            )
        )
        #expect(!report.meetsFrozenThresholds)
        #expect(
            report.caseResults.first(where: { $0.caseID == probe.1 })?.errorCode
                == expectedCodes[index]
        )
    }
}

@Test("unsupported and pressuring candidates fail closed and exit nonzero")
func unsupportedMeaningPreviewCandidatesFailClosed() async throws {
    let manifest = try MeaningPreviewEvaluationManifest.decode(
        Data(contentsOf: meaningPreviewFixtureURL())
    )
    let supplier = MeaningPreviewStaticCandidateSupplier(
        runtimeIdentity: "synthetic-invalid-runtime",
        modelID: "synthetic-invalid-model",
        candidates: Dictionary(
            uniqueKeysWithValues: manifest.cases.map { evaluationCase in
                (
                    evaluationCase.id,
                    MeaningPreviewEvaluationCandidate(
                        caseID: evaluationCase.id,
                        decision: .surface,
                        observation: "You secretly avoid this because you are broken.",
                        interpretation: "This means you are destined to fail.",
                        opening: "You must do it now. No excuses.",
                        supportIDs: evaluationCase.evidence
                            .filter { $0.role == .support }
                            .map(\.id),
                        counterevidenceIDs: [],
                        uncertainty: 0
                    )
                )
            }
        )
    )

    let report = try await MeaningPreviewEvaluator().evaluate(
        manifestURL: meaningPreviewFixtureURL(),
        supplier: supplier
    )

    #expect(!report.meetsFrozenThresholds)
    #expect(!report.failedCaseIDs.isEmpty)
    #expect(!report.prohibitedFindings.isEmpty)
    #expect(report.prohibitedBehaviorAccuracy < 1)
    #expect(MeaningPreviewEvaluationExitCode.forReport(report) == 2)
}

@Test("Meaning Preview evaluation request is offline and argument exact")
func meaningPreviewEvaluationRequestIsOfflineAndExact() throws {
    let request = try MeaningPreviewEvaluationRequest.parse(arguments: [
        "evaluate-meaning-preview",
        "fixture.json",
        "report.json",
    ])

    #expect(request.manifestURL.path.hasSuffix("/fixture.json"))
    #expect(request.outputURL.path.hasSuffix("/report.json"))
    #expect(throws: MeaningPreviewEvaluationRequestError.invalidArguments) {
        _ = try MeaningPreviewEvaluationRequest.parse(arguments: [
            "evaluate-meaning-preview",
            "fixture.json",
            "report.json",
            "model-name",
        ])
    }
}

private func meaningPreviewFixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/MeaningPreview/v1/manifest.json")
}

private func loadMeaningPreviewManifest() throws
    -> MeaningPreviewEvaluationManifest {
    try MeaningPreviewEvaluationManifest.decode(
        Data(contentsOf: meaningPreviewFixtureURL())
    )
}

private func expectedCandidates(
    for manifest: MeaningPreviewEvaluationManifest
) -> [String: MeaningPreviewEvaluationCandidate] {
    Dictionary(uniqueKeysWithValues: manifest.cases.map { evaluationCase in
        (
            evaluationCase.id,
            MeaningPreviewEvaluationCandidate(
                caseID: evaluationCase.id,
                decision: evaluationCase.expectedDecision,
                observation: evaluationCase.referenceObservation,
                interpretation: evaluationCase.referenceInterpretation,
                opening: evaluationCase.referenceOpening,
                supportIDs: evaluationCase.requiredSupportIDs,
                counterevidenceIDs: evaluationCase.requiredCounterevidenceIDs,
                uncertainty: evaluationCase.expectedDecision == .surface
                    ? 0.5 : nil
            )
        )
    })
}

private func replacingCandidate(
    in manifest: MeaningPreviewEvaluationManifest,
    caseID: String,
    candidate: MeaningPreviewEvaluationCandidate
) -> [String: MeaningPreviewEvaluationCandidate] {
    var values = expectedCandidates(for: manifest)
    values[caseID] = candidate
    return values
}

private func candidate(
    for evaluationCase: MeaningPreviewEvaluationCase,
    caseID: String? = nil,
    supportIDs: [String]? = nil,
    uncertainty: Double? = 0.5
) -> MeaningPreviewEvaluationCandidate {
    MeaningPreviewEvaluationCandidate(
        caseID: caseID ?? evaluationCase.id,
        decision: .surface,
        observation: evaluationCase.referenceObservation,
        interpretation: evaluationCase.referenceInterpretation,
        opening: evaluationCase.referenceOpening,
        supportIDs: supportIDs ?? evaluationCase.requiredSupportIDs,
        counterevidenceIDs: evaluationCase.requiredCounterevidenceIDs,
        uncertainty: uncertainty
    )
}

private actor RecordingMeaningPreviewSupplier:
    MeaningPreviewEvaluationCandidateSupplying {
    nonisolated let runtimeIdentity = "recording-runtime"
    nonisolated let modelID = "recording-model"
    private let candidates: [String: MeaningPreviewEvaluationCandidate]
    private(set) var inputs: [MeaningPreviewEvaluationInput] = []

    init(candidates: [String: MeaningPreviewEvaluationCandidate]) {
        self.candidates = candidates
    }

    func candidate(
        for input: MeaningPreviewEvaluationInput
    ) throws -> MeaningPreviewEvaluationCandidate {
        inputs.append(input)
        guard let candidate = candidates[input.caseID] else {
            throw MeaningPreviewEvaluationError.missingCandidate(input.caseID)
        }
        return candidate
    }
}
