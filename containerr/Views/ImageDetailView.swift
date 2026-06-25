//
//  ImageDetailView.swift
//  containerr
//

import SwiftUI

struct ImageDetailView: View {
    @Bindable var store: ContainerStore
    let image: ImageSummary
    var onRun: (ImageSummary) -> Void
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Form {
                LabeledContent("Digest", value: image.shortDigest)
                LabeledContent("Size", value: ByteFormat.string(image.sizeBytes))
                if !image.platforms.isEmpty {
                    LabeledContent("Platforms", value: image.platforms.joined(separator: ", "))
                }
                if let created = image.configuration.creationDate {
                    LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .formStyle(.grouped)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { onRun(image) } label: {
                    Label("Run", systemImage: "play.fill")
                }
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .disabled(store.busy.contains(image.id))
        .confirmationDialog("Delete \(image.reference)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await store.deleteImage(image) } }
        } message: {
            Text("This removes the image from local storage.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(image.reference)
                .font(.title2.bold())
                .textSelection(.enabled)
            Text(ByteFormat.string(image.sizeBytes))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
