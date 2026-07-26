import CAMAssistantCore
import Foundation

func runOrchestrationLockProbe(arguments: [String]) -> Int32 {
    guard arguments.count == 3 else {
        FileHandle.standardError.write(
            Data("usage: cam-assistant orchestration-lock-probe LOCK_DIRECTORY RUN_ID\n".utf8)
        )
        return 64
    }
    do {
        let store = try OrchestrationLeaseStore(rootDirectory: URL(filePath: arguments[1]))
        let lease = try store.acquire(runID: arguments[2], ownerID: "cam-assistant-lock-probe")
        try store.release(lease)
        print("orchestration lock available")
        return 0
    } catch OrchestrationLeaseError.heldByAnotherOwner {
        print("orchestration lock held")
        return 75
    } catch {
        FileHandle.standardError.write(Data("orchestration lock probe failed: \(error)\n".utf8))
        return 1
    }
}
