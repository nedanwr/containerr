//
//  ContainerListView.swift
//  containerr
//

import SwiftUI

struct ContainerListView: View {
    @Bindable var store: ContainerStore

    var body: some View {
        List(selection: $store.selection) {
            ForEach(store.containers) { container in
                ContainerRow(container: container, busy: store.busy.contains(container.id))
                    .tag(container.id)
                    .contextMenu { rowActions(for: container) }
            }
        }
        .overlay {
            if store.containers.isEmpty, case .ready = store.phase {
                ContentUnavailableView("No Containers", systemImage: "shippingbox",
                    description: Text("Run one with `container run` to see it here."))
            }
        }
    }

    @ViewBuilder
    private func rowActions(for container: ContainerSnapshot) -> some View {
        if container.state == .running {
            Button("Stop") { Task { await store.stop(container.id) } }
        } else {
            Button("Start") { Task { await store.start(container.id) } }
        }
        Divider()
        Button("Delete", role: .destructive) { Task { await store.delete(container.id) } }
    }
}

private struct ContainerRow: View {
    let container: ContainerSnapshot
    let busy: Bool

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(state: container.state)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.id)
                    .font(.body.weight(.medium))
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if busy { ProgressView().controlSize(.small) }
        }
        .padding(.vertical, 2)
    }
}
