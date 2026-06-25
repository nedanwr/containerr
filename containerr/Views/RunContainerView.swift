//
//  RunContainerView.swift
//  containerr
//
//  Sheet for creating & running a new container via `container run`.
//

import SwiftUI

struct RunContainerView: View {
    let store: ContainerStore
    @Environment(\.dismiss) private var dismiss

    @State private var options: RunOptions

    init(store: ContainerStore, prefillImage: String = "") {
        self.store = store
        var initial = RunOptions()
        initial.image = prefillImage
        _options = State(initialValue: initial)
    }
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var customMemory = false
    @State private var customMemoryText = ""
    @AppStorage(SettingsKey.overrideResourceLimits) private var overrideLimits = false

    private var policy: ResourcePolicy { ResourcePolicy(override: overrideLimits) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Image", text: $options.image,
                              prompt: Text("docker.io/library/nginx:latest"))
                    TextField("Name", text: $options.name,
                              prompt: Text("optional"))
                }

                Section("Port Mappings") {
                    StringListEditor(items: $options.ports, placeholder: "8080:80")
                }
                Section("Environment") {
                    StringListEditor(items: $options.env, placeholder: "KEY=value")
                }
                Section("Volumes") {
                    StringListEditor(items: $options.volumes, placeholder: "/host/path:/container/path")
                }

                Section("Resources") {
                    VStack(alignment: .leading) {
                        LabeledContent("CPUs", value: "\(options.cpus)")
                        Slider(
                            value: Binding(
                                get: { Double(options.cpus) },
                                set: { options.cpus = Int($0) }),
                            in: 1...Double(policy.maxCPUs), step: 1)
                        Text(overrideLimits
                            ? "Containers can use all \(policy.maxCPUs) cores. No cores are held back for macOS."
                            : "Containers can use up to \(policy.maxCPUs) cores. The other \(ResourcePolicy.cpuReserve) stay free for macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Memory", value: ResourcePolicy.formatMiB(options.memoryMiB))
                        if customMemory {
                            TextField("MB", text: $customMemoryText)
                                .onChange(of: customMemoryText) { applyCustomMemory() }
                            Text("Choose from 256 MB to \(ResourcePolicy.formatMiB(policy.maxMemoryMiB)).")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Slider(
                                value: Binding(
                                    get: { Double(policy.stopIndex(for: options.memoryMiB)) },
                                    set: { options.memoryMiB = policy.memoryStops[Int($0)] }),
                                in: 0...Double(policy.memoryStops.count - 1), step: 1)
                        }
                        Toggle("Custom amount", isOn: $customMemory)
                            .onChange(of: customMemory) {
                                if customMemory { customMemoryText = "\(options.memoryMiB)" }
                                else { options.memoryMiB = policy.nearestStop(options.memoryMiB) }
                            }
                        Text(overrideLimits
                            ? "Containers can use up to \(ResourcePolicy.formatMiB(policy.maxMemoryMiB)). No memory is held back for macOS."
                            : "Containers can use up to \(ResourcePolicy.formatMiB(policy.maxMemoryMiB)). Memory is set aside in full, so \(ResourcePolicy.formatMiB(policy.memoryReserveMiB)) stays free for macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField("Command", text: $options.command,
                              prompt: Text("override entrypoint (optional)"))
                    Toggle("Remove on exit (--rm)", isOn: $options.removeOnExit)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Run") { Task { await submit() } }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(submitting)
            }
            .padding()
        }
        .frame(width: 460, height: 560)
        .overlay {
            if submitting {
                Color.black.opacity(0.1)
                ProgressView("Starting container…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    /// Parses the custom field, clamping to the range allowed by the policy.
    private func applyCustomMemory() {
        guard let value = Int(customMemoryText.trimmingCharacters(in: .whitespaces)) else { return }
        options.memoryMiB = min(max(value, 256), policy.maxMemoryMiB)
    }

    private func submit() async {
        if let invalid = options.validationError {
            errorMessage = invalid
            return
        }
        submitting = true
        errorMessage = nil
        let failure = await store.create(options)
        submitting = false
        if let failure {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

/// Dynamic list of free-text rows with add/remove controls.
private struct StringListEditor: View {
    @Binding var items: [String]
    let placeholder: String

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack {
                TextField(placeholder, text: $items[index])
                Button {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        Button {
            items.append("")
        } label: {
            Label("Add", systemImage: "plus.circle")
        }
        .buttonStyle(.borderless)
    }
}
