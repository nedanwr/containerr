//
//  ContainerDetailView.swift
//  containerr
//

import SwiftUI

struct ContainerDetailView: View {
    @Bindable var store: ContainerStore
    let container: ContainerSnapshot
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            TabView {
                InfoTab(container: container)
                    .tabItem { Label("Info", systemImage: "info.circle") }
                LogsTab(store: store, id: container.id)
                    .tabItem { Label("Logs", systemImage: "text.alignleft") }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if container.state == .running {
                    Button { store.openShell(container.id) } label: {
                        Label("Open Shell", systemImage: "terminal")
                    }
                    Button { Task { await store.stop(container.id) } } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                } else {
                    Button { Task { await store.start(container.id) } } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .disabled(store.busy.contains(container.id))
        .confirmationDialog("Delete \(container.id)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await store.delete(container.id) } }
        } message: {
            Text("This permanently removes the container.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.id).font(.title2.bold())
                Text(container.image)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            StatusBadge(state: container.state)
        }
        .padding()
    }
}

private struct InfoTab: View {
    let container: ContainerSnapshot

    var body: some View {
        Form {
            LabeledContent("Status", value: container.state.label)
            if let ip = container.ipv4 { LabeledContent("IP Address", value: ip) }
            if let p = container.configuration.platform {
                LabeledContent("Platform", value: "\(p.os ?? "?")/\(p.architecture ?? "?")")
            }
            if let created = container.configuration.creationDate {
                LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
            }
            if !container.publishedPorts.isEmpty {
                Section("Published Ports") {
                    ForEach(container.publishedPorts) { port in
                        // Build plain Strings so port numbers aren't run through
                        // LocalizedStringKey's number formatter (which adds commas).
                        let host = "\(port.hostAddress ?? "0.0.0.0"):\(port.hostPort)"
                        let target = "→ \(port.containerPort)/\(port.proto ?? "tcp")"
                        LabeledContent(host, value: target)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct LogsTab: View {
    let store: ContainerStore
    let id: String
    @State private var buffer = LogBuffer()
    @State private var following = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(buffer.text.isEmpty ? "No log output." : buffer.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                Color.clear.frame(height: 1).id("bottom")
            }
            .onChange(of: buffer.text) {
                if following { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .overlay(alignment: .topTrailing) {
            Toggle(isOn: $following) {
                Label("Follow", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .padding(8)
        }
        // Re-subscribe when the container or follow mode changes.
        .task(id: "\(id)-\(following)") {
            buffer.clear()
            if following {
                for await chunk in ContainerCLI().streamLogs(id: id) {
                    buffer.append(chunk)
                }
            } else {
                buffer.append((try? await ContainerCLI().logs(id: id)) ?? "")
            }
        }
    }
}
