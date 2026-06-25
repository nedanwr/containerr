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

    @State private var options = RunOptions()
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var customMemory = false
    @State private var customMemoryText = ""

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
                            in: 1...Double(Self.maxCPUs), step: 1)
                        Text("Containers can use up to \(Self.maxCPUs) cores. The other \(Self.cpuReserve) stay free for macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Memory", value: Self.formatMiB(options.memoryMiB))
                        if customMemory {
                            TextField("MB", text: $customMemoryText)
                                .onChange(of: customMemoryText) { applyCustomMemory() }
                            Text("Choose from 256 MB to \(Self.formatMiB(Self.maxMemoryMiB)).")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Slider(
                                value: Binding(
                                    get: { Double(Self.stopIndex(for: options.memoryMiB)) },
                                    set: { options.memoryMiB = Self.memoryStops[Int($0)] }),
                                in: 0...Double(Self.memoryStops.count - 1), step: 1)
                        }
                        Toggle("Custom amount", isOn: $customMemory)
                            .onChange(of: customMemory) {
                                if customMemory { customMemoryText = "\(options.memoryMiB)" }
                                else { options.memoryMiB = Self.nearestStop(options.memoryMiB) }
                            }
                        Text("Containers can use up to \(Self.formatMiB(Self.maxMemoryMiB)). Memory is set aside in full, so \(Self.formatMiB(Self.memoryReserveMiB)) stays free for macOS.")
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

    // Host limits, so the sliders can't exceed the machine's real resources.

    /// Cores kept strictly for the host system (e.g. 14-core → 10 assignable).
    private static let cpuReserve = 4
    private static let maxCPUs = max(1, ProcessInfo.processInfo.activeProcessorCount - cpuReserve)

    private static let totalMemoryMiB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
    /// Memory is allocated in full (no dynamic scaling), so we reserve the
    /// larger of 6 GB or 25% of total RAM for the host system.
    private static let memoryReserveMiB = max(6144, totalMemoryMiB / 4)
    private static let maxMemoryMiB = max(256, totalMemoryMiB - memoryReserveMiB)

    /// Standard slider stops, capped to what's available after the reserve.
    private static let memoryStops: [Int] = {
        let all = [256, 512, 1024, 2048, 4096, 8192, 16384]
        let usable = all.filter { $0 <= maxMemoryMiB }
        return usable.isEmpty ? [256] : usable
    }()

    /// Index of the stop at or just below `mib` (for restoring slider position).
    private static func stopIndex(for mib: Int) -> Int {
        let idx = memoryStops.lastIndex { $0 <= mib } ?? 0
        return idx
    }

    private static func nearestStop(_ mib: Int) -> Int {
        memoryStops.min { abs($0 - mib) < abs($1 - mib) } ?? memoryStops[0]
    }

    private static func formatMiB(_ mib: Int) -> String {
        mib >= 1024 && mib % 1024 == 0
            ? "\(mib / 1024) GB"
            : "\(mib) MB"
    }

    /// Parses the custom field, clamping to the allowed range.
    private func applyCustomMemory() {
        guard let value = Int(customMemoryText.trimmingCharacters(in: .whitespaces)) else { return }
        options.memoryMiB = min(max(value, 256), Self.maxMemoryMiB)
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
