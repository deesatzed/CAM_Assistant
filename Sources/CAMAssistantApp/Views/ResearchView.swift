import CAMAssistantCore
import SwiftUI

struct ResearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            Label("Local research", systemImage: "text.magnifyingglass")
            TextField("Research question", text: $model.researchQuery).textFieldStyle(.roundedBorder)
            Button("Create Local Research Plan", action: model.beginLocalResearch)
            Button("Keep Local Research Plan", action: model.keepLocalResearchPlan)
                .disabled(model.currentResearchRun == nil)
            if let error = model.researchError { Text(error).foregroundStyle(.red) }
            VStack(spacing: 10) {
                Text(model.researchPresentation.statusMessage)
                if let provenance = model.currentResearchRun?.provenance {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Repository idea evidence · commit \(provenance.sourceCommit.prefix(12)) · confidence \(Int(provenance.confidence * 100))%")
                            .font(.caption)
                        ForEach(provenance.citations, id: \.passageID) { citation in
                            Text("Cited: \(citation.passageID)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("Counterevidence: \(provenance.counterevidence.joined(separator: " · "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Validation: \(provenance.validationExperiment)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                }
                Text("Facts require local citation support. Inferences and contradiction candidates remain separate for review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Web, cloud, CAM, automatic retention, and scheduling are disabled. Keep saves only this local plan checkpoint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            if !model.retainedResearchPlans.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kept local research plans")
                        .font(.headline)
                    ForEach(model.retainedResearchPlans, id: \.run.id) { plan in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.run.queries.joined(separator: " · "))
                                Text("Checkpoint: \(plan.run.checkpoint.phase.rawValue), version \(plan.run.checkpoint.stateVersion)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Resume") { model.resumeLocalResearchPlan(plan) }
                        }
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
            }
        }.padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Research. \(model.researchPresentation.statusMessage). External execution and automatic retention are disabled.")
    }
}
