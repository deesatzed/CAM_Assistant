import SwiftUI

struct RepositoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Selected local repository") {
                TextField("Repository path", text: $model.repositoryPath)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Local Git repository path")
                Button("Inspect Repository") {
                    model.inspectSelectedRepository()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .accessibilityHint("Reads local Git evidence only. It does not modify the repository.")
                Button("Save Repository Source", action: model.saveRepositorySource)
                    .disabled(model.repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Retains this local path only. It does not inspect, index, or modify a repository.")
                Button("Index Committed Sources") {
                    model.indexSelectedRepository()
                }
                .disabled(model.isRepositoryIndexing)
                .accessibilityHint("Copies permitted committed files into the local vault. It does not write to the repository or invoke CAM.")
                Button("Scan Committed Observations") {
                    model.scanSelectedRepositoryObservations()
                }
                .disabled(model.isRepositoryIndexing || model.isScanningRepositoryObservations)
                .accessibilityHint("Reads only the inspected clean commit for TODO, FIXME, and Swift declaration review evidence.")
                Button("Analyze Repository Evidence Locally") {
                    model.analyzeSelectedRepositorySemantics()
                }
                .disabled(
                    model.isRepositoryIndexing
                        || model.isScanningRepositoryObservations
                        || model.isRepositorySemanticAnalyzing
                )
                .accessibilityHint(
                    "Health-checks the selected loopback model and analyzes bounded evidence from the inspected clean commit. No fallback, CAM call, repository write, or automatic retention occurs."
                )
                if model.isRepositoryIndexing {
                    HStack {
                        ProgressView("Indexing committed sources locally")
                            .accessibilityLabel("Repository indexing in progress")
                        Button("Cancel", action: model.cancelRepositoryIndexing)
                    }
                }
                if model.isScanningRepositoryObservations {
                    ProgressView("Scanning committed observations locally")
                        .accessibilityLabel("Repository observation scan in progress")
                }
                if model.isRepositorySemanticAnalyzing {
                    HStack {
                        ProgressView(
                            "Analyzing bounded repository evidence locally"
                        )
                        .accessibilityLabel(
                            "Local repository evidence analysis in progress"
                        )
                        Button("Cancel Local Analysis", action: model.cancelRepositorySemanticAnalysis)
                    }
                }
            }

            if let status = model.repositorySemanticStatus {
                Section("Local analysis status") {
                    Text(status)
                        .accessibilityLabel(
                            "Repository semantic analysis status. \(status)"
                        )
                }
            }

            if let analysis = model.repositorySemanticAnalysis,
               let candidate = analysis.validatedCandidate {
                Section("Ephemeral local-model candidate") {
                    Text(candidate.statement)
                        .textSelection(.enabled)
                    LabeledContent("Model", value: analysis.modelID)
                    LabeledContent("Runtime", value: analysis.runtimeIdentity)
                    LabeledContent(
                        "Commit",
                        value: String(
                            analysis.snapshotCommit.prefix(12)
                        )
                    )
                    LabeledContent(
                        "Confidence",
                        value: String(
                            format: "%.2f",
                            candidate.confidence
                        )
                    )
                    ForEach(candidate.claims, id: \.id) { claim in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(claim.id)
                                .font(.subheadline)
                            Text(claim.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "Selected claim \(claim.id). \(claim.description)"
                        )
                    }
                    Text(
                        "Nothing is retained until you explicitly Keep or choose a promotion action."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Support evidence") {
                    ForEach(candidate.support, id: \.id) { evidence in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "\(evidence.filePath):\(evidence.line) · \(evidence.symbol)"
                            )
                            .font(.subheadline)
                            Text(evidence.excerpt)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "Support evidence \(evidence.filePath), line \(evidence.line), symbol \(evidence.symbol). \(evidence.excerpt)"
                        )
                    }
                }

                Section("Counterevidence") {
                    ForEach(
                        candidate.counterevidence,
                        id: \.id
                    ) { evidence in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "\(evidence.filePath):\(evidence.line) · \(evidence.symbol)"
                            )
                            .font(.subheadline)
                            Text(evidence.excerpt)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "Counterevidence \(evidence.filePath), line \(evidence.line), symbol \(evidence.symbol). \(evidence.excerpt)"
                        )
                    }
                }

                Section("Explicit idea review") {
                    TextField(
                        "Idea title",
                        text: $model.repositoryIdeaTitle
                    )
                    TextField("Rejected alternative", text: $model.repositorySemanticRejectedAlternative)
                    TextField(
                        "Smallest validation experiment",
                        text:
                            $model
                                .repositoryIdeaValidationExperiment
                    )
                    Button("Create Evidence-Complete Idea", action: model.createRepositorySemanticIdeaProposal)
                    Text(
                        "Creating the card remains local and proposal-only. Keeping, rejecting, or promoting it is always a separate explicit action."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let proposal = model.repositoryIdeaProposal {
                        LabeledContent(
                            "Proposal",
                            value: proposal.kind.rawValue
                        )
                        LabeledContent(
                            "Idea ID",
                            value: proposal.ideaID
                        )
                        HStack {
                            Button("Keep Idea") {
                                model.retainRepositoryIdea(.kept)
                            }
                            Button("Reject Idea") {
                                model.retainRepositoryIdea(.rejected)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(
                            "Semantic repository idea decision"
                        )
                        if let disposition =
                            model.repositoryIdeaDisposition {
                            LabeledContent(
                                "Decision",
                                value:
                                    disposition.rawValue.capitalized
                            )
                        }
                        Button(
                            "Save as Local Task",
                            action:
                                model.saveRepositoryIdeaAsLocalTask
                        )
                        .disabled(
                            model.repositoryIdeaDisposition == .rejected
                        )
                        Button(
                            "Create & Keep Research Plan",
                            action:
                                model.createRepositoryIdeaResearchPlan
                        )
                        .disabled(
                            model.repositoryIdeaDisposition == .rejected
                        )
                        Button(
                            "Save Codex Plan Handoff",
                            action:
                                model.saveRepositoryIdeaAsCodexPlan
                        )
                        .disabled(
                            model.repositoryIdeaDisposition == .rejected
                        )
                    }
                }
            }

            if !model.repositorySources.isEmpty {
                Section("Saved local repositories") {
                    Text("Choose a saved path, then inspect it explicitly. Saving a source does not grant repository or CAM access. Removing a saved path preserves vault bytes, provenance, snapshots, jobs, and ideas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.repositorySources) { source in
                        HStack {
                            Button(source.canonicalPath) {
                                model.selectRepositorySource(source)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use saved repository path \(source.canonicalPath)")
                            Spacer()
                            Button("Remove") {
                                model.removeRepositorySource(source.id)
                            }
                            .accessibilityLabel("Remove saved repository path \(source.canonicalPath)")
                            .accessibilityHint("Removes only the saved path selection. Existing local evidence and history are preserved.")
                        }
                    }
                }
            }

            if !model.repositoryJobs.isEmpty {
                Section("Recent repository jobs") {
                    Text("Status-only local history. These jobs never invoke CAM, use a network, or write to the selected repository.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.repositoryJobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.canonicalPath)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("\(job.statusLabel) · \(job.attemptLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let result = job.resultLabel {
                                Text(result)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let failure = job.failureLabel {
                                Text(failure)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                            if let action = job.availableAction {
                                switch action {
                                case .cancel:
                                    Button("Cancel") {
                                        model.cancelRepositoryJob(job.id)
                                    }
                                    .accessibilityHint("Cancels only this local repository indexing job.")
                                case .resume:
                                    Button("Resume") {
                                        model.resumeRepositoryJob(job.id)
                                    }
                                    .disabled(model.isRepositoryIndexing)
                                    .accessibilityHint("Retries this same local job within its bounded attempt limit.")
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Repository job \(job.statusLabel), \(job.attemptLabel), path \(job.canonicalPath)")
                    }
                }
            }

            if !model.repositoryObservations.isEmpty {
                Section("Commit-cited observations") {
                    Text("Observations are review evidence, not architectural or behavior claims.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.repositoryObservations) { observation in
                        Button {
                            model.selectedRepositoryObservationID = observation.id
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(observation.filePath):\(observation.line) · \(observation.symbol)")
                                    .font(.subheadline)
                                Text(observation.statement)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Commit \(observation.commitShort)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(model.selectedRepositoryObservationID == observation.id ? Color.accentColor.opacity(0.15) : .clear)
                        .accessibilityLabel("\(observation.filePath), line \(observation.line), symbol \(observation.symbol), commit \(observation.commitShort). \(observation.statement)")
                    }
                }

                Section("Proposal-only idea card") {
                    TextField("Idea title", text: $model.repositoryIdeaTitle)
                    TextField("Counterevidence", text: $model.repositoryIdeaCounterevidence)
                    TextField("Smallest validation experiment", text: $model.repositoryIdeaValidationExperiment)
                    Button("Create Proposal-Only Idea", action: model.createRepositoryIdeaProposal)
                        .disabled(model.selectedRepositoryObservationID == nil)
                    Text("This does not copy code, create a task, invoke CAM, or alter the repository.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let proposal = model.repositoryIdeaProposal {
                        LabeledContent("Proposal", value: proposal.kind.rawValue)
                        LabeledContent("Commit", value: String(proposal.sourceCommit.prefix(12)))
                        LabeledContent("Idea ID", value: proposal.ideaID)
                        HStack {
                            Button("Keep Idea") {
                                model.retainRepositoryIdea(.kept)
                            }
                            Button("Reject Idea") {
                                model.retainRepositoryIdea(.rejected)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Repository idea decision")
                        if let disposition = model.repositoryIdeaDisposition {
                            LabeledContent("Decision", value: disposition.rawValue.capitalized)
                        }
                        Button("Save as Local Task", action: model.saveRepositoryIdeaAsLocalTask)
                            .disabled(model.repositoryIdeaDisposition == .rejected)
                            .accessibilityHint("Creates a cited local-read task. It does not execute code, invoke CAM, or change the repository.")
                        if let task = model.repositoryIdeaTask {
                            LabeledContent("Saved task", value: task.id)
                        }
                        Button("Create & Keep Research Plan", action: model.createRepositoryIdeaResearchPlan)
                            .disabled(model.repositoryIdeaDisposition == .rejected)
                            .accessibilityHint("Creates a cited local research plan and opens Research. It does not acquire sources, invoke CAM, call a network, or change the repository.")
                        if let researchPlan = model.repositoryIdeaResearchPlan {
                            LabeledContent("Research plan", value: researchPlan.id)
                        }
                        Button("Save Codex Plan Handoff", action: model.saveRepositoryIdeaAsCodexPlan)
                            .disabled(model.repositoryIdeaDisposition == .rejected)
                            .accessibilityHint("Saves a cited local proposal for a future Codex planning session. It does not invoke Codex, CAM, a network, or alter the repository.")
                        if let codexPlan = model.repositoryIdeaCodexPlan {
                            LabeledContent("Codex plan handoff", value: codexPlan.id)
                        }
                    }
                }
            }

            if !model.repositoryIdeaHistory.rows.isEmpty {
                Section("Retained repository ideas") {
                    Button("Reload Retained Ideas", action: model.reloadRepositoryIdeaHistory)
                        .accessibilityHint("Reads locally retained repository idea decisions. It does not rescan or alter any repository.")
                    ForEach(model.repositoryIdeaHistory.rows) { idea in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(idea.title)
                                .font(.subheadline)
                            Text("\(idea.dispositionLabel) · \(idea.evidenceLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Counterevidence: \(idea.counterevidence)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Validation: \(idea.validationExperiment)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(idea.title). \(idea.dispositionLabel). \(idea.evidenceLabel). Counterevidence: \(idea.counterevidence). Validation: \(idea.validationExperiment)")
                    }
                }
            }

            if let presentation = model.repositoryPresentation {
                Section("Read-only receipt") {
                    LabeledContent("Path", value: presentation.canonicalPath)
                    LabeledContent("Branch", value: presentation.branch)
                    LabeledContent("Commit", value: presentation.commitShort)
                    LabeledContent("State", value: presentation.statusLabel)
                    LabeledContent("License", value: presentation.licenseLabel)
                    LabeledContent("Evidence", value: presentation.evidenceLabel)
                    Text(presentation.miningStatus)
                        .foregroundStyle(.secondary)
                    if let index = model.repositoryIndexPresentation {
                        Text(index.statusLabel)
                        Text(index.miningStatus)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Inspect a selected repository",
                    systemImage: "folder.badge.gearshape",
                    description: Text("Inspection records local Git and file evidence without altering the repository. Idea cards are proposals only; CAM mining remains disabled.")
                )
            }

            if let error = model.repositoryError {
                Text(error)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Repository inspection error: \(error)")
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel("Repositories. Read-only local inspection and proposal-only ideas. CAM mining is disabled.")
    }
}
