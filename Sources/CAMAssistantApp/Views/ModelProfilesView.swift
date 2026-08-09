import CAMAssistantCore
import SwiftUI

struct ModelProfilesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Local server (LM Studio / Ollama)") {
                Picker("Preset", selection: $model.localEndpointPreset) {
                    Text("LM Studio (1234)").tag(LocalEndpointPreset.lmStudio)
                    Text("Ollama (11434)").tag(LocalEndpointPreset.ollama)
                    Text("Custom").tag(LocalEndpointPreset.custom)
                }
                TextField(
                    "Local endpoint (loopback only)",
                    text: $model.localEndpointDraft
                )
                .textFieldStyle(.roundedBorder)
                .disabled(model.localEndpointPreset != .custom)
                .onChange(of: model.localEndpointPreset) { _, preset in
                    model.applyLocalEndpointPreset(preset)
                }

                HStack {
                    Button(
                        model.isRefreshingLocalCatalog
                            ? "Refreshing…"
                            : "Refresh Models From Server"
                    ) {
                        model.refreshLocalModelCatalog()
                    }
                    .disabled(model.isRefreshingLocalCatalog)
                    Button("Apply Selected Local Model") {
                        model.applySelectedLocalModelFromCatalog()
                    }
                    .disabled(model.selectedLocalCatalogModelID.isEmpty)
                }

                if model.localCatalogModelIDs.isEmpty {
                    Text("Click Refresh to load models from the running local server.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Model on server",
                        selection: $model.selectedLocalCatalogModelID
                    ) {
                        Text("Choose a model").tag("")
                        ForEach(model.localCatalogModelIDs, id: \.self) { id in
                            Text(model.friendlyLocalModelLabel(for: id))
                                .tag(id)
                                .help(id)
                        }
                    }
                    if !model.selectedLocalCatalogModelID.isEmpty {
                        Text("Full id: \(model.selectedLocalCatalogModelID)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }

                if let err = model.localCatalogError {
                    Text(err).foregroundStyle(.red)
                }
                if let status = model.localCatalogStatus {
                    Text(status).foregroundStyle(.secondary)
                }
            }

            Section("Active local profile") {
                if let settings = model.modelSettings,
                   let profile = settings.activeProfile {
                    LabeledContent("Profile", value: profile.id)
                    LabeledContent("Revision", value: String(profile.revision))
                    if let local = profile.assignment(for: .local) {
                        LabeledContent("Model", value: local.modelID)
                        LabeledContent(
                            "Endpoint",
                            value: local.localEndpoint ?? "—"
                        )
                    }
                    Text(settings.availabilityMessage)
                        .foregroundStyle(.secondary)
                    if let localHealth = model.localModelHealth {
                        Label(
                            "\(localHealth.modelID) is available at \(localHealth.endpointIdentity)",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                    } else if let localHealthError = model.localModelHealthError {
                        Text(localHealthError).foregroundStyle(.red)
                    }
                    Button(
                        model.isCheckingLocalModel
                            ? "Checking Local Model…"
                            : "Health-check Selected Local Model"
                    ) {
                        model.checkSelectedLocalModel()
                    }
                    .disabled(model.isCheckingLocalModel)
                } else {
                    Text(
                        model.modelSettingsError
                            ?? "No active local model profile yet. Refresh models and Apply."
                    )
                    .foregroundStyle(.secondary)
                }
                Button("Reload Profile State") {
                    model.reloadModelSettings()
                }
            }

            Section("OpenRouter (cloud)") {
                Text(
                    "Uses HTTPS openrouter.ai only. The API key is stored in the macOS Keychain on this Mac, not in chat logs."
                )
                .foregroundStyle(.secondary)

                SecureField(
                    "OpenRouter API key",
                    text: $model.openRouterAPIKeyDraft
                )
                .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save API Key") {
                        model.saveOpenRouterAPIKey()
                    }
                    Button("Clear Key") {
                        model.clearOpenRouterAPIKey()
                    }
                }
                if let keyStatus = model.openRouterKeyStatus {
                    Text(keyStatus).foregroundStyle(.secondary)
                }

                TextField(
                    "OpenRouter endpoint",
                    text: $model.openRouterEndpointDraft
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button(
                        model.isRefreshingOpenRouterCatalog
                            ? "Refreshing…"
                            : "Refresh OpenRouter Models"
                    ) {
                        model.refreshOpenRouterCatalog()
                    }
                    .disabled(model.isRefreshingOpenRouterCatalog)
                    Button("Apply OpenRouter Model") {
                        model.applySelectedOpenRouterModel()
                    }
                    .disabled(model.selectedOpenRouterModelID.isEmpty)
                }

                if model.openRouterCatalogModelIDs.isEmpty {
                    Text("Save an API key, then Refresh to list OpenRouter models.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "OpenRouter model",
                        selection: $model.selectedOpenRouterModelID
                    ) {
                        Text("Choose a model").tag("")
                        ForEach(
                            model.openRouterCatalogModelIDs,
                            id: \.self
                        ) { id in
                            Text(id).tag(id)
                        }
                    }
                }

                Toggle(
                    "Enable OpenRouter for chat",
                    isOn: $model.openRouterEnabled
                )
                .onChange(of: model.openRouterEnabled) { _, enabled in
                    model.setOpenRouterEnabled(enabled)
                }

                if let err = model.openRouterError {
                    Text(err).foregroundStyle(.red)
                }
                if let status = model.openRouterStatus {
                    Text(status).foregroundStyle(.secondary)
                }
                if let health = model.openRouterHealth {
                    Label(
                        "\(health.modelID) ready via OpenRouter",
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                }
                Button(
                    model.isCheckingOpenRouter
                        ? "Checking OpenRouter…"
                        : "Health-check OpenRouter Model"
                ) {
                    model.checkOpenRouterModel()
                }
                .disabled(model.isCheckingOpenRouter)
            }

            Section("Safety") {
                Text(
                    "Local endpoints must be loopback only. OpenRouter is optional outbound HTTPS to openrouter.ai after you paste a key. Cloud Claude/Grok marker routes remain separately gated."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel("Model profile settings")
        .onAppear {
            model.reloadModelSettings()
            model.reloadOpenRouterSettings()
            model.applyLocalEndpointPreset(model.localEndpointPreset)
        }
    }
}

enum LocalEndpointPreset: String, CaseIterable, Identifiable {
    case lmStudio
    case ollama
    case custom

    var id: String { rawValue }
}
