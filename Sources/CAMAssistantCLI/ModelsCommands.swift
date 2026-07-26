import CAMAssistantCore
import Foundation

func runModelCommand(arguments: [String]) -> Int32 {
    do {
        let command = try ModelCommand.parse(arguments)
        let registry = try ModelRegistry(
            stateURL: ModelProfileStorage.defaultStateURL()
        )
        let result = try ModelCommandExecutor(registry: registry).execute(command)
        print(renderModelCommandResult(result))
        return 0
    } catch ModelCommandExecutionError.outboundPolicyRequired {
        FileHandle.standardError.write(
            Data("This operation is unavailable until the privacy/outbound policy milestone is verified.\n".utf8)
        )
        return 77
    } catch ModelCommandExecutionError.proofGateRequired {
        FileHandle.standardError.write(
            Data("This operation is unavailable until its required evaluation and privacy proof gates are verified.\n".utf8)
        )
        return 77
    } catch {
        FileHandle.standardError.write(
            Data("Model command failed. Run `cam-assistant models` with a supported local command.\n".utf8)
        )
        return 64
    }
}

private func renderModelCommandResult(_ result: ModelCommandResult) -> String {
    switch result {
    case let .active(profile):
        guard let profile else { return "No active local model profile." }
        return renderProfile(profile)
    case let .profiles(profiles):
        guard !profiles.isEmpty else { return "No local model profiles." }
        return profiles.map(renderProfile).joined(separator: "\n\n")
    case let .profile(profile):
        return renderProfile(profile)
    case let .changed(receipt):
        return "Profile \(receipt.profileID) \(receipt.kind.rawValue); revision \(receipt.currentRevision); receipt \(receipt.id.uuidString)."
    case .localCatalogNotConfigured:
        return "No local catalog is configured. `models catalog --live` remains unavailable until the privacy/outbound policy milestone is verified."
    }
}

private func renderProfile(_ profile: ModelProfile) -> String {
    let assignments = profile.assignments
        .sorted { $0.key.rawValue < $1.key.rawValue }
        .map { role, assignment in
            "\(role.rawValue): \(assignment.provider.rawValue)/\(assignment.modelID)"
        }
        .joined(separator: ", ")
    return "Profile \(profile.id), revision \(profile.revision). \(assignments)"
}
