//
//  PullImageView.swift
//  containerr
//
//  Sheet for pulling an image via `container image pull`.
//

import SwiftUI

struct PullImageView: View {
    let store: ContainerStore
    @Environment(\.dismiss) private var dismiss

    @State private var reference = ""
    @State private var pulling = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pull Image")
                .font(.headline)

            TextField("Image reference", text: $reference,
                      prompt: Text("docker.io/library/alpine:latest"))
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await submit() } }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                if pulling {
                    ProgressView().controlSize(.small)
                    Text("Pulling…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Pull") { Task { await submit() } }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(pulling || reference.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
    }

    private func submit() async {
        let ref = reference.trimmingCharacters(in: .whitespaces)
        guard !ref.isEmpty else { return }
        pulling = true
        errorMessage = nil
        let failure = await store.pull(ref)
        pulling = false
        if let failure { errorMessage = failure } else { dismiss() }
    }
}
