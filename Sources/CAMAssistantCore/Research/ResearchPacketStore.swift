import Foundation

/// Explicit local retention for verified research packets. Callers must build
/// the packet through `ResearchCoordinator.packet` first; this store never
/// acquires sources, generates findings, or retains raw source bytes.
public final class ResearchPacketStore {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> [ResearchPacket] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([ResearchPacket].self, from: Data(contentsOf: url))
    }

    public func keep(_ packet: ResearchPacket) throws {
        var packets = try load()
        packets.removeAll { $0.runID == packet.runID }
        packets.append(packet)
        packets.sort { $0.runID < $1.runID }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(packets).write(to: url, options: .atomic)
    }
}
