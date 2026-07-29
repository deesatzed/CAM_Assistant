import CAMAssistantCore
import Foundation

func runResearchCommand(arguments: [String]) async -> Int32 {
    do {
        let command = try ResearchAcquisitionCommand.parse(
            arguments: arguments
        )
        print(try await ResearchAcquisitionCommandExecutor().execute(command))
        return 0
    } catch ResearchAcquisitionCommandError.invalidArguments {
        FileHandle.standardError.write(
            Data(
                """
                usage: cam-assistant research acquire --approve-exact VAULT_ROOT RUN_ID QUERY PUBLIC_HTTPS_DOCUMENT_URL
                """.appending("\n").utf8
            )
        )
        return 64
    } catch {
        FileHandle.standardError.write(
            Data("research acquisition failed\n".utf8)
        )
        return 1
    }
}
