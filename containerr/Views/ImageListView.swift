//
//  ImageListView.swift
//  containerr
//

import SwiftUI

/// Shared byte formatter for image sizes.
enum ByteFormat {
    static func string(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

struct ImageListView: View {
    @Bindable var store: ContainerStore

    var body: some View {
        List(selection: $store.imageSelection) {
            ForEach(store.filteredImages) { image in
                ImageRow(image: image, busy: store.busy.contains(image.id))
                    .tag(image.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await store.deleteImage(image) }
                        }
                    }
            }
        }
        .overlay {
            if store.filteredImages.isEmpty, case .ready = store.phase {
                if store.images.isEmpty {
                    ContentUnavailableView("No Images", systemImage: "photo.stack",
                        description: Text("Pull one to get started."))
                } else {
                    ContentUnavailableView.search
                }
            }
        }
    }
}

private struct ImageRow: View {
    let image: ImageSummary
    let busy: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(image.reference)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(image.shortDigest) · \(ByteFormat.string(image.sizeBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if busy { ProgressView().controlSize(.small) }
        }
        .padding(.vertical, 2)
    }
}
