#!/usr/bin/env swift

import Foundation

let scriptURL = URL(filePath: #filePath)
let repositoryRoot = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let arguments = Array(CommandLine.arguments.dropFirst())
let manifestURL = arguments.first.map { URL(fileURLWithPath: $0) }
    ?? repositoryRoot.appending(path: "Tests/Fixtures/Retrieval/manifest.json")
let outputURL = arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? repositoryRoot.appending(path: "docs/evidence/task-06-retrieval-report.json")

let process = Process()
process.currentDirectoryURL = repositoryRoot
process.executableURL = URL(filePath: "/usr/bin/env")
process.arguments = [
    "swift",
    "run",
    "--scratch-path",
    ".swift-build",
    "cam-assistant",
    "evaluate-retrieval",
    manifestURL.path,
    outputURL.path,
]
var environment = ProcessInfo.processInfo.environment
environment["SWIFTPM_MODULECACHE_OVERRIDE"] =
    repositoryRoot.appending(path: ".swift-build/module-cache").path
environment["CLANG_MODULE_CACHE_PATH"] =
    repositoryRoot.appending(path: ".swift-build/module-cache").path
process.environment = environment

try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
