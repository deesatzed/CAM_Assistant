import Foundation
import Testing

@Test("governing project truth is self-contained in the repository")
func governingProjectTruthIsRepositoryLocal() throws {
    let root = portabilityRepositoryRoot()
    let truthFiles = [
        "AGENTS.md",
        "GOAL.md",
        "GOAL_FINISH_WIKI.md",
        "STANDARDS.md",
        "IMPLEMENT.md",
        "DECISIONS.md",
        "PROGRESS.md",
        "TASK_QUEUE.md",
        "README.md",
        "docs/VERIFICATION_REPORT.md",
    ]

    for path in truthFiles {
        let content = try String(
            contentsOf: root.appending(path: path),
            encoding: .utf8
        )
        #expect(
            !content.contains("../GOAL"),
            "\(path) must not depend on a goal outside the repository"
        )
        #expect(
            !content.contains("../docs/"),
            "\(path) must not depend on planning files outside the repository"
        )
    }
}

@Test("aggregate verifier exposes repository portability gates")
func aggregateVerifierExposesPortabilityGates() throws {
    let script = try String(
        contentsOf: portabilityRepositoryRoot()
            .appending(path: "scripts/verify.sh"),
        encoding: .utf8
    )

    #expect(script.contains("portability)"))
    #expect(script.contains("fresh-clone)"))
    #expect(script.contains("verify-portability.sh"))
    #expect(script.contains("verify-fresh-clone.sh"))
}

private func portabilityRepositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
