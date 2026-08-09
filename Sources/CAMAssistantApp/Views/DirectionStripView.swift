import CAMAssistantCore
import SwiftUI

struct DirectionStripView: View {
    @ObservedObject var model: AppModel
    @State private var showPersonSheet = false
    @State private var showPromiseSheet = false
    @State private var showNorthStarSheet = false
    @State private var showTalkSheet = false
    @State private var showManageSheet = false
    @State private var personPendingRemoval: DirectionPerson?
    @State private var promisePendingRemoval: DirectionPromise?

    private var presentation: DirectionPresentation {
        DirectionPresentation(profile: model.directionProfile)
    }

    var body: some View {
        GroupBox("Direction") {
            VStack(alignment: .leading, spacing: 10) {
                Text(presentation.peopleLine)
                    .font(.body)
                Text(presentation.promiseLine)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(presentation.northStarLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !model.directionProfile.openPromises.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.directionProfile.openPromises.prefix(3)) {
                            promise in
                            HStack(alignment: .firstTextBaseline) {
                                Text(promise.text)
                                    .lineLimit(2)
                                Spacer(minLength: 8)
                                Button("Done") {
                                    model.markDirectionPromiseDone(id: promise.id)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityHint(
                                    "Marks this promise complete. You can reopen it under Manage."
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 12) {
                    Button("Add person") { showPersonSheet = true }
                    Button("Add promise") { showPromiseSheet = true }
                    Button("Edit north star") { showNorthStarSheet = true }
                    Button("Manage") { showManageSheet = true }
                    Button("Talk") { showTalkSheet = true }
                        .buttonStyle(.borderedProminent)
                }

                if let status = model.directionStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Direction. People, promises, and Talk.")
        .sheet(isPresented: $showPersonSheet) {
            DismissibleSheetChrome(title: "Who matters?") {
                DirectionPersonSheet(model: model)
            }
            .frame(minWidth: 400, minHeight: 280)
        }
        .sheet(isPresented: $showPromiseSheet) {
            DismissibleSheetChrome(title: "One small promise") {
                DirectionPromiseSheet(model: model)
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .sheet(isPresented: $showNorthStarSheet) {
            DismissibleSheetChrome(title: "Your direction") {
                DirectionNorthStarSheet(model: model)
            }
            .frame(minWidth: 400, minHeight: 280)
        }
        .sheet(isPresented: $showTalkSheet) {
            DismissibleSheetChrome(title: "Talk", doneTitle: "Close") {
                DirectionTalkView(model: model)
            }
            .frame(minWidth: 440, minHeight: 360)
            .onDisappear { model.clearDirectionTalk() }
        }
        .sheet(isPresented: $showManageSheet) {
            DismissibleSheetChrome(title: "Manage Direction", doneTitle: "Done") {
                DirectionManageView(
                    model: model,
                    personPendingRemoval: $personPendingRemoval,
                    promisePendingRemoval: $promisePendingRemoval
                )
            }
            .frame(minWidth: 480, minHeight: 420)
        }
        .confirmationDialog(
            "Remove this person?",
            isPresented: Binding(
                get: { personPendingRemoval != nil },
                set: { if !$0 { personPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let person = personPendingRemoval {
                    model.removeDirectionPerson(id: person.id)
                }
                personPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                personPendingRemoval = nil
            }
        } message: {
            Text(
                personPendingRemoval.map {
                    "\($0.name) will be removed from Direction on this Mac."
                } ?? ""
            )
        }
        .confirmationDialog(
            "Remove this promise?",
            isPresented: Binding(
                get: { promisePendingRemoval != nil },
                set: { if !$0 { promisePendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let promise = promisePendingRemoval {
                    model.removeDirectionPromise(id: promise.id)
                }
                promisePendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                promisePendingRemoval = nil
            }
        } message: {
            Text(
                promisePendingRemoval.map {
                    "“\($0.text)” will be deleted from Direction."
                } ?? ""
            )
        }
    }
}

struct DirectionManageView: View {
    @ObservedObject var model: AppModel
    @Binding var personPendingRemoval: DirectionPerson?
    @Binding var promisePendingRemoval: DirectionPromise?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("People and promises stay on this Mac. Remove only if you are sure.")
                    .foregroundStyle(.secondary)

                GroupBox("People") {
                    if model.directionProfile.people.isEmpty {
                        Text("No people yet. Use Add person on Home.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.directionProfile.people) { person in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.name).font(.headline)
                                        if !person.relation.isEmpty {
                                            Text(person.relation)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button("Remove", role: .destructive) {
                                        personPendingRemoval = person
                                    }
                                }
                            }
                        }
                    }
                }

                GroupBox("Open promises") {
                    if model.directionProfile.openPromises.isEmpty {
                        Text("No open promises.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.directionProfile.openPromises) {
                                promise in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(promise.text)
                                    Text("Toward \(promise.toward)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Button("Mark done") {
                                            model.markDirectionPromiseDone(
                                                id: promise.id
                                            )
                                        }
                                        Button("Remove", role: .destructive) {
                                            promisePendingRemoval = promise
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                let closed = model.directionProfile.promises.filter { !$0.isOpen }
                if !closed.isEmpty {
                    GroupBox("Done promises") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(closed) { promise in
                                HStack {
                                    Text(promise.text)
                                        .strikethrough()
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Reopen") {
                                        model.reopenDirectionPromise(
                                            id: promise.id
                                        )
                                    }
                                    Button("Remove", role: .destructive) {
                                        promisePendingRemoval = promise
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DirectionPersonSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var relation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name a real person. Not an AI.")
                .foregroundStyle(.secondary)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Relation (optional)", text: $relation)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Save") {
                    model.addDirectionPerson(name: name, relation: relation)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(24)
    }
}

struct DirectionPromiseSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var toward = "shared good"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Something you will do for someone who matters, or a shared good."
            )
            .foregroundStyle(.secondary)
            TextField("Promise", text: $text)
                .textFieldStyle(.roundedBorder)
            if model.directionProfile.people.isEmpty {
                TextField("Toward (person or shared good)", text: $toward)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Toward", selection: $toward) {
                    Text("shared good").tag("shared good")
                    ForEach(model.directionProfile.people) { person in
                        Text(person.name).tag(person.name)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Save") {
                    model.addDirectionPromise(text: text, toward: toward)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(24)
        .onAppear {
            if let first = model.directionProfile.people.first {
                toward = first.name
            }
        }
    }
}

struct DirectionNorthStarSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var northStar = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("One short line you own. CAM will not decide for you.")
                .foregroundStyle(.secondary)
            TextField("North star", text: $northStar, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Save") {
                    model.setDirectionNorthStar(northStar)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .onAppear { northStar = model.directionProfile.northStar }
    }
}

struct DirectionTalkView: View {
    @ObservedObject var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Partner chat about your people, promises, or Library. "
                    + "Claims about saved items need real sources."
            )
            .foregroundStyle(.secondary)

            if let result = model.directionTalkResult {
                GroupBox("Partner") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.text)
                            .textSelection(.enabled)
                        Text(modeLabel(result.mode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let response = result.response,
                           !response.citations.isEmpty
                        {
                            Button("Keep this answer") {
                                model.keepDirectionTalkResponse()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            TextField("What is on your mind?", text: $draft, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .disabled(model.isDirectionTalking)

            HStack {
                Spacer()
                if model.isDirectionTalking {
                    ProgressView()
                }
                Button("Send") {
                    model.sendDirectionTalk(draft)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty || model.isDirectionTalking
                )
            }
        }
        .padding(24)
    }

    private func modeLabel(_ mode: DirectionTalkMode) -> String {
        switch mode {
        case .offlineCoach:
            "Local AI is not ready."
        case .profileContinuity:
            "From your Direction — not Library sources."
        case .libraryGrounded:
            "Grounded in your Library."
        case .matchingPassages:
            "Matching passages from your Library."
        case .admitAbsence:
            "Not enough in your Library."
        }
    }
}
