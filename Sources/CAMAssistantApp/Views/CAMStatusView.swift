import CAMAssistantCore
import SwiftUI
import UniformTypeIdentifiers

struct CAMStatusView: View {
    let status: CAMIntegrationStatus

    @State private var executableURL: URL?
    @State private var configurationURL: URL?
    @State private var databaseURL: URL?
    @State private var runtimePin: CAMVerifiedRuntimePin?
    @State private var runtimePinIsCurrentSession = false
    @State private var receipt: CAMRuntimeProbeReceipt?
    @State private var closedToolReceipt: CAMClosedToolReceipt?
    @State private var closedToolReplayed = false
    @State private var message: String?
    @State private var didLoadRestartState = false
    @State private var selectsExecutable = false
    @State private var selectsConfiguration = false
    @State private var selectsDatabase = false
    @State private var pinOperation = CAMOperationLifecycleState()
    @State private var probeOperation = CAMOperationLifecycleState()
    @State private var liveOperation = CAMOperationLifecycleState()
    @State private var pinTask: Task<Void, Never>?
    @State private var probeTask: Task<Void, Never>?
    @State private var liveTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section("Contract") {
                LabeledContent("Ownership", value: status.contractIdentity)
                LabeledContent("Adapter", value: status.runtimeMessage)
                Text(
                    "This screen can inspect explicitly selected local bytes "
                        + "and run one closed statistics tool against a copy."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Selected runtime") {
                selectionRow(
                    title: "Executable",
                    url: executableURL,
                    buttonTitle: "Select CAM Executable…"
                ) {
                    selectsExecutable = true
                }
                selectionRow(
                    title: "Configuration",
                    url: configurationURL,
                    buttonTitle: "Select Configuration…"
                ) {
                    selectsConfiguration = true
                }
                selectionRow(
                    title: "Database",
                    url: databaseURL,
                    buttonTitle: "Select Database…"
                ) {
                    selectsDatabase = true
                }
                Button("Pin Selected Runtime") {
                    pinSelectedRuntime()
                }
                .disabled(!canPin || isPinning || isProbing)
            }

            if let runtimePin {
                Section(
                    runtimePinIsCurrentSession
                        ? "Pinned identity"
                        : "Historical pinned identity"
                ) {
                    LabeledContent(
                        "Identity SHA-256",
                        value: runtimePin.identitySHA256
                    )
                    LabeledContent(
                        "Executable SHA-256",
                        value: runtimePin.executableSHA256
                    )
                    LabeledContent(
                        "Configuration SHA-256",
                        value: runtimePin.configurationSHA256
                    )
                    LabeledContent(
                        "Database SHA-256",
                        value: runtimePin.databaseSHA256
                    )
                    Button("Run Disposable Statistics Probe") {
                        runDisposableProbe(runtimePin)
                    }
                    .disabled(
                        isPinning || isProbing || isRunningClosedTool
                            || !runtimePinIsCurrentSession
                    )
                    Button("Run Closed CAM Statistics Tool") {
                        runClosedStatisticsTool(runtimePin)
                    }
                    .disabled(
                        isPinning || isProbing || isRunningClosedTool
                            || !runtimePinIsCurrentSession
                    )
                    if !runtimePinIsCurrentSession {
                        Text(
                            "Re-pin this runtime before running another probe."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Text(
                        "The donor database is never passed to CAM. The selected "
                            + "config and database bytes are copied into the "
                            + "app cache, and donor hashes are checked before "
                            + "and after native inspection."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        "The closed tool starts only pinned CAM statistics inside "
                            + "a sandboxed disposable workspace. It is not mining."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let receipt, receipt.status == .verified,
               let statistics = receipt.statistics {
                if runtimePinIsCurrentSession {
                    Section("Verified disposable receipt") {
                        receiptDetails(receipt, statistics: statistics)
                    }
                } else {
                    Section("Historical receipt") {
                        receiptDetails(receipt, statistics: statistics)
                    }
                }
            }

            if let closedToolReceipt {
                Section("Closed statistics receipt") {
                    closedToolReceiptDetails(closedToolReceipt)
                }
            }

            Section("Authority boundary") {
                Text(
                    "Mining, provider calls, MCP serving, and personal-corpus mutation remain disabled."
                )
                if isPinning {
                    HStack {
                        ProgressView("Hashing selected bytes…")
                        Button("Cancel Runtime Pin") {
                            cancelRuntimePin()
                        }
                    }
                } else if isProbing {
                    HStack {
                        ProgressView("Probing copied CAM state…")
                        Button("Cancel Disposable Probe") {
                            cancelDisposableProbe()
                        }
                    }
                } else if isRunningClosedTool {
                    HStack {
                        ProgressView("Running closed statistics on copied CAM state…")
                        Button("Cancel Closed CAM Statistics Tool") {
                            cancelClosedStatisticsTool()
                        }
                    }
                } else if let message {
                    Text(message)
                        .foregroundStyle(
                            receipt?.status == .verified
                                ? Color.green
                                : Color.secondary
                        )
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $selectsExecutable,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if let selected = selectedURL(from: result) {
                invalidatePin()
                executableURL = selected
            }
        }
        .fileImporter(
            isPresented: $selectsConfiguration,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if let selected = selectedURL(from: result) {
                invalidatePin()
                configurationURL = selected
            }
        }
        .fileImporter(
            isPresented: $selectsDatabase,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if let selected = selectedURL(from: result) {
                invalidatePin()
                databaseURL = selected
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "CAM. Local runtime pinning and disposable read-only inspection. "
                + "Mining and personal corpus mutation are disabled."
        )
        .task {
            restoreHistoricalRuntimeState()
        }
        .onDisappear {
            pinOperation.invalidate()
            probeOperation.invalidate()
            liveOperation.invalidate()
            pinTask?.cancel()
            probeTask?.cancel()
            liveTask?.cancel()
            pinTask = nil
            probeTask = nil
            liveTask = nil
        }
    }

    @ViewBuilder
    private func selectionRow(
        title: String,
        url: URL?,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(url?.path ?? "Not selected")
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(url == nil ? .secondary : .primary)
                Button(buttonTitle, action: action)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) runtime selection")
    }

    @ViewBuilder
    private func receiptDetails(
        _ receipt: CAMRuntimeProbeReceipt,
        statistics: CAMStatisticsSnapshot
    ) -> some View {
        LabeledContent(
            "Methodologies",
            value: "\(statistics.methodologyCount)"
        )
        LabeledContent(
            "Source repositories",
            value: "\(statistics.sourceRepositoryCount)"
        )
        LabeledContent(
            "Federation configured",
            value: statistics.federationEnabled ? "Yes" : "No"
        )
        LabeledContent("Tool", value: receipt.toolID)
        LabeledContent(
            "Output SHA-256",
            value: receipt.outputSHA256 ?? "Unavailable"
        )
        Text(
            "Native statistics are validated and digested. The "
                + "copied config and corpus are automatically removed."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func closedToolReceiptDetails(
        _ receipt: CAMClosedToolReceipt
    ) -> some View {
        LabeledContent("Tool", value: receipt.toolID.rawValue)
        LabeledContent("Status", value: receipt.status.rawValue)
        LabeledContent("Attempts", value: "\(receipt.attemptCount)")
        LabeledContent(
            "Process exit",
            value: receipt.processExitCode.map(String.init) ?? "Unavailable"
        )
        LabeledContent(
            "Sandboxed",
            value: receipt.sandboxed ? "Yes" : "No"
        )
        LabeledContent(
            "Receipt replayed",
            value: closedToolReplayed ? "Yes" : "No"
        )
        if let statistics = receipt.statistics {
            LabeledContent(
                "Methodologies",
                value: "\(statistics.methodologyCount)"
            )
            LabeledContent(
                "Source repositories",
                value: "\(statistics.sourceRepositoryCount)"
            )
        }
        Text(
            receipt.status == .verified
                ? "Typed output and independent copied-state statistics matched."
                : "Closed tool did not verify: \(receipt.failureCode ?? "unknown failure")."
        )
        .font(.caption)
        .foregroundStyle(
            receipt.status == .verified ? Color.secondary : Color.orange
        )
    }

    private var canPin: Bool {
        executableURL != nil
            && configurationURL != nil
            && databaseURL != nil
    }

    private var isPinning: Bool {
        pinOperation.isRunning
    }

    private var isProbing: Bool {
        probeOperation.isRunning
    }

    private var isRunningClosedTool: Bool {
        liveOperation.isRunning
    }

    private func selectedURL(
        from result: Result<[URL], Error>
    ) -> URL? {
        guard case let .success(urls) = result else {
            message = "The selected file could not be opened."
            return nil
        }
        return urls.first
    }

    private func invalidatePin() {
        pinOperation.invalidate()
        probeOperation.invalidate()
        liveOperation.invalidate()
        pinTask?.cancel()
        probeTask?.cancel()
        liveTask?.cancel()
        pinTask = nil
        probeTask = nil
        liveTask = nil
        runtimePin = nil
        runtimePinIsCurrentSession = false
        receipt = nil
        closedToolReceipt = nil
        closedToolReplayed = false
        message = nil
    }

    private func pinSelectedRuntime() {
        guard let executableURL, let configurationURL, let databaseURL else {
            return
        }
        receipt = nil
        message = nil
        pinTask?.cancel()
        let generation = pinOperation.begin()
        pinTask = Task {
            let outcome: Result<
                CAMVerifiedRuntimePin,
                CAMRuntimePinViewFailure
            >
            do {
                let pin = try await CAMRuntimeInspector().inspectBounded(
                    executableURL: executableURL,
                    configurationURL: configurationURL,
                    databaseURL: databaseURL
                )
                outcome = .success(pin)
            } catch CAMRuntimeProbeError.processCancelled {
                outcome = .failure(.cancelled)
            } catch CAMRuntimeProbeError.processTimedOut {
                outcome = .failure(.timedOut)
            } catch {
                outcome = .failure(.other(String(describing: error)))
            }
            guard pinOperation.accepts(generation),
                  self.executableURL == executableURL,
                  self.configurationURL == configurationURL,
                  self.databaseURL == databaseURL else {
                return
            }
            switch outcome {
            case let .success(pin):
                do {
                    let store = try runtimeRestartStateStore()
                    try store.save(pin: pin)
                    runtimePin = pin
                    runtimePinIsCurrentSession = true
                    message =
                        "Runtime bytes pinned. No CAM process was started."
                } catch {
                    runtimePin = nil
                    runtimePinIsCurrentSession = false
                    message =
                        "Runtime pinning finished, but its local restart "
                        + "state could not be saved."
                }
            case .failure(.cancelled):
                runtimePin = nil
                runtimePinIsCurrentSession = false
                message = "Runtime pinning cancelled."
            case .failure(.timedOut):
                runtimePin = nil
                runtimePinIsCurrentSession = false
                message = "Runtime pinning timed out."
            case let .failure(.other(description)):
                runtimePin = nil
                runtimePinIsCurrentSession = false
                message = "Runtime pinning failed: \(description)"
            }
            pinOperation.finish(generation)
            pinTask = nil
        }
    }

    private func runDisposableProbe(_ pin: CAMVerifiedRuntimePin) {
        receipt = nil
        message = nil
        probeTask?.cancel()
        let generation = probeOperation.begin()
        probeTask = Task {
            let outcome: Result<
                CAMRuntimeProbeReceipt,
                CAMRuntimeProbeViewFailure
            >
            do {
                guard let caches = FileManager.default.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                ).first else {
                    throw CAMStatusViewError.cacheUnavailable
                }
                let workspace = caches
                    .appending(path: "CAMAssistant", directoryHint: .isDirectory)
                    .appending(path: "CAMRuntimeProbes", directoryHint: .isDirectory)
                let result = await CAMDisposableStatisticsProbe().attempt(
                    pin: pin,
                    workspaceRoot: workspace
                )
                outcome = .success(result)
            } catch {
                outcome = .failure(.other(String(describing: error)))
            }
            guard probeOperation.accepts(generation),
                  runtimePin?.identitySHA256 == pin.identitySHA256 else {
                return
            }
            switch outcome {
            case let .success(result):
                do {
                    let store = try runtimeRestartStateStore()
                    try store.save(receipt: result, for: pin)
                    receipt = result
                    if result.status == .verified {
                        message = "Copied-state statistics verified."
                    } else {
                        message =
                            "Disposable CAM probe \(result.status.rawValue): "
                            + (result.failureCode ?? "unknown failure")
                    }
                } catch {
                    receipt = nil
                    message =
                        "The disposable probe finished, but its local "
                        + "receipt could not be saved."
                }
            case let .failure(.other(description)):
                receipt = nil
                message = "Disposable CAM probe failed: \(description)"
            }
            probeOperation.finish(generation)
            probeTask = nil
        }
    }

    private func runClosedStatisticsTool(_ pin: CAMVerifiedRuntimePin) {
        closedToolReceipt = nil
        closedToolReplayed = false
        message = nil
        liveTask?.cancel()
        let generation = liveOperation.begin()
        liveTask = Task {
            let outcome: Result<
                CAMClosedToolExecutionResult,
                CAMRuntimeProbeViewFailure
            >
            do {
                guard let caches = FileManager.default.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                ).first else {
                    throw CAMStatusViewError.cacheUnavailable
                }
                let workspace = caches
                    .appending(path: "CAMAssistant", directoryHint: .isDirectory)
                    .appending(path: "CAMClosedToolRuns", directoryHint: .isDirectory)
                let request = try CAMClosedToolRequest(
                    toolID: .statistics,
                    runtimeIdentitySHA256: pin.identitySHA256,
                    idempotencyKey: "native-stats-\(pin.identitySHA256.prefix(12))-\(UUID().uuidString)",
                    maximumAttempts: 2,
                    timeoutSeconds: 60
                )
                let result = await CAMClosedToolExecutor().attempt(
                    request: request,
                    pin: pin,
                    workspaceRoot: workspace
                )
                outcome = .success(result)
            } catch {
                outcome = .failure(.other(String(describing: error)))
            }
            guard liveOperation.accepts(generation),
                  runtimePin?.identitySHA256 == pin.identitySHA256,
                  runtimePinIsCurrentSession else {
                return
            }
            switch outcome {
            case let .success(result):
                closedToolReceipt = result.receipt
                closedToolReplayed = result.replayed
                if result.receipt.status == .verified {
                    message = "Closed copied-state CAM statistics verified."
                } else {
                    message = "Closed CAM tool \(result.receipt.status.rawValue): "
                        + (result.receipt.failureCode ?? "unknown failure")
                }
            case let .failure(.other(description)):
                closedToolReceipt = nil
                closedToolReplayed = false
                message = "Closed CAM statistics tool failed: \(description)"
            }
            liveOperation.finish(generation)
            liveTask = nil
        }
    }

    private func cancelRuntimePin() {
        pinOperation.invalidate()
        pinTask?.cancel()
        pinTask = nil
        runtimePin = nil
        runtimePinIsCurrentSession = false
        message = "Runtime pinning cancelled."
    }

    private func cancelDisposableProbe() {
        probeOperation.invalidate()
        probeTask?.cancel()
        probeTask = nil
        receipt = nil
        message = "Disposable CAM probe cancelled."
    }

    private func cancelClosedStatisticsTool() {
        liveOperation.invalidate()
        liveTask?.cancel()
        liveTask = nil
        closedToolReceipt = nil
        closedToolReplayed = false
        message = "Closed CAM statistics tool cancelled."
    }

    private func restoreHistoricalRuntimeState() {
        guard !didLoadRestartState else { return }
        didLoadRestartState = true
        do {
            guard let state = try runtimeRestartStateStore().load() else {
                return
            }
            executableURL = state.pin.executableURL
            configurationURL = state.pin.configurationURL
            databaseURL = state.pin.databaseURL
            runtimePin = state.pin
            runtimePinIsCurrentSession = false
            receipt = state.latestReceipt
            message =
                "Historical runtime evidence restored. Re-pin before "
                + "running another probe."
        } catch {
            runtimePin = nil
            runtimePinIsCurrentSession = false
            receipt = nil
            message =
                "Saved runtime evidence is invalid or unavailable and "
                + "was ignored."
        }
    }

    private func runtimeRestartStateStore() throws
        -> CAMRuntimeRestartStateStore {
        CAMRuntimeRestartStateStore(
            url: try LocalVaultPaths.rootURL()
                .appending(path: CAMRuntimeRestartStateStore.fileName)
        )
    }
}

struct CAMOperationLifecycleState: Equatable {
    private var generation = UUID()
    private(set) var isRunning = false

    mutating func begin() -> UUID {
        generation = UUID()
        isRunning = true
        return generation
    }

    mutating func invalidate() {
        generation = UUID()
        isRunning = false
    }

    mutating func finish(_ candidate: UUID) {
        guard accepts(candidate) else { return }
        isRunning = false
    }

    func accepts(_ candidate: UUID) -> Bool {
        generation == candidate
    }
}

private enum CAMRuntimePinViewFailure: Error {
    case cancelled
    case timedOut
    case other(String)
}

private enum CAMRuntimeProbeViewFailure: Error {
    case other(String)
}

private enum CAMStatusViewError: Error {
    case cacheUnavailable
}
