import CAMAssistantCore
import Foundation

func runVaultCommand(arguments: [String]) -> Int32 {
    do {
        let command = try VaultCommand.parse(arguments: arguments)
        print(try VaultCommandExecutor().execute(command))
        return 0
    } catch VaultCommandError.invalidArguments {
        FileHandle.standardError.write(
            Data(
                """
                usage:
                  cam-assistant vault backup SOURCE_VAULT_ROOT PACKAGE.camvault
                  cam-assistant vault validate PACKAGE.camvault
                  cam-assistant vault restore PACKAGE.camvault DESTINATION_VAULT_ROOT
                """.appending("\n").utf8
            )
        )
        return 64
    } catch {
        FileHandle.standardError.write(
            Data("vault operation failed\n".utf8)
        )
        return 1
    }
}

