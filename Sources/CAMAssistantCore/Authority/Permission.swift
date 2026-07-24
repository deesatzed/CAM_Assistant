public enum Permission: String, Codable, CaseIterable, Hashable, Sendable {
    case readLocal
    case writeLocal
    case readClipboard
    case watchFolders
    case network
    case execute
    case delete
    case account
    case spend
}

public enum ApprovalClass: String, Codable, Sendable {
    case none
    case notify
    case confirm
    case exact
}
