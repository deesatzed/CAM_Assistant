import Foundation

public enum ModuleHealth: Equatable, Sendable {
    case healthy
    case unhealthy(reason: String)
    case unknown
}

public enum ModuleStatus: Equatable, Sendable {
    case available
    case disabled
    case degraded(reason: String)
}

public struct ModuleCapability: Equatable, Hashable, Sendable {
    public let id: String
    public let moduleID: String

    public init(id: String, moduleID: String) {
        self.id = id
        self.moduleID = moduleID
    }
}

public enum ModuleRegistryError: Error, Equatable {
    case duplicateID(String)
    case moduleNotFound(String)
    case coreModuleCannotBeDisabled(String)
    case undeclaredPermission(moduleID: String, permission: Permission)
}

public final class ModuleRegistry {
    public typealias HealthProvider = (ModuleManifest) -> ModuleHealth

    private let manifestDirectory: URL
    private let stateURL: URL
    private let healthProvider: HealthProvider
    private let lock = NSRecursiveLock()
    private var manifestsByID: [String: ModuleManifest] = [:]
    private var state: RegistryState

    public init(
        manifestDirectory: URL,
        stateURL: URL,
        healthProvider: @escaping HealthProvider = { _ in .healthy }
    ) throws {
        self.manifestDirectory = manifestDirectory
        self.stateURL = stateURL
        self.healthProvider = healthProvider
        self.state = try RegistryState.load(from: stateURL)
        try reload()
    }

    public func reload() throws {
        lock.lock()
        defer { lock.unlock() }
        let files = try FileManager.default.contentsOfDirectory(
            at: manifestDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var discovered: [String: ModuleManifest] = [:]
        for file in files
        where file.pathExtension.lowercased() == "json"
            && file.standardizedFileURL != stateURL.standardizedFileURL {
            let manifest = try ModuleManifest.decodeValidated(Data(contentsOf: file))
            guard discovered[manifest.id] == nil else {
                throw ModuleRegistryError.duplicateID(manifest.id)
            }
            discovered[manifest.id] = manifest
        }

        manifestsByID = discovered
        state.enabledModuleIDs.formUnion(
            discovered.values.filter(\.isCore).map(\.id)
        )
        state.enabledModuleIDs.formIntersection(discovered.keys)
    }

    public func enable(_ moduleID: String) throws {
        try mutateState(
            { state, manifest in
                state.enabledModuleIDs.insert(manifest.id)
            },
            forModule: moduleID
        )
    }

    public func disable(_ moduleID: String) throws {
        try mutateState(
            { state, manifest in
                guard !manifest.isCore else {
                    throw ModuleRegistryError.coreModuleCannotBeDisabled(manifest.id)
                }
                state.enabledModuleIDs.remove(manifest.id)
                state.permissionGrants.removeValue(forKey: manifest.id)
            },
            forModule: moduleID
        )
    }

    public func grant(_ permissions: Set<Permission>, to moduleID: String) throws {
        try mutateState(
            { state, manifest in
                let declared = Set(manifest.permissions)
                if let invalid = permissions.first(where: { !declared.contains($0) }) {
                    throw ModuleRegistryError.undeclaredPermission(
                        moduleID: manifest.id,
                        permission: invalid
                    )
                }
                state.permissionGrants[manifest.id] = permissions
            },
            forModule: moduleID
        )
    }

    public func isEnabled(_ moduleID: String) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _ = try manifest(for: moduleID)
        return state.enabledModuleIDs.contains(moduleID)
    }

    public func grantedPermissions(for moduleID: String) throws -> Set<Permission> {
        lock.lock()
        defer { lock.unlock() }
        _ = try manifest(for: moduleID)
        return state.permissionGrants[moduleID] ?? []
    }

    public func capabilities() throws -> [ModuleCapability] {
        lock.lock()
        defer { lock.unlock() }
        return manifestsByID.values
            .filter { state.enabledModuleIDs.contains($0.id) }
            .filter { manifest in
                let granted = state.permissionGrants[manifest.id] ?? []
                return Set(manifest.permissions).isSubset(of: granted)
            }
            .filter {
                if case .healthy = healthProvider($0) { return true }
                return false
            }
            .flatMap { manifest in
                manifest.capabilities.map {
                    ModuleCapability(id: $0, moduleID: manifest.id)
                }
            }
            .sorted { $0.id < $1.id }
    }

    public func status(for moduleID: String) throws -> ModuleStatus {
        lock.lock()
        defer { lock.unlock() }
        let manifest = try manifest(for: moduleID)
        guard state.enabledModuleIDs.contains(moduleID) else { return .disabled }
        switch healthProvider(manifest) {
        case .healthy:
            return .available
        case let .unhealthy(reason):
            return .degraded(reason: reason)
        case .unknown:
            return .degraded(reason: "Health unknown")
        }
    }

    public func manifests() -> [ModuleManifest] {
        lock.lock()
        defer { lock.unlock() }
        return manifestsByID.values.sorted { $0.id < $1.id }
    }

    private func mutateState(
        _ mutation: (inout RegistryState, ModuleManifest) throws -> Void,
        forModule moduleID: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        let manifest = try manifest(for: moduleID)
        let previous = state
        do {
            try mutation(&state, manifest)
            try state.save(to: stateURL)
        } catch {
            state = previous
            throw error
        }
    }

    private func manifest(for moduleID: String) throws -> ModuleManifest {
        guard let manifest = manifestsByID[moduleID] else {
            throw ModuleRegistryError.moduleNotFound(moduleID)
        }
        return manifest
    }
}

private struct RegistryState: Codable, Equatable {
    var enabledModuleIDs: Set<String> = []
    var permissionGrants: [String: Set<Permission>] = [:]

    static func load(from url: URL) throws -> RegistryState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return RegistryState()
        }
        return try JSONDecoder().decode(
            RegistryState.self,
            from: Data(contentsOf: url)
        )
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: [.atomic])
    }
}
