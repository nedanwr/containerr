//
//  DaemonUnavailableView.swift
//  containerr
//

import SwiftUI

struct DaemonUnavailableView: View {
    @Bindable var store: ContainerStore
    let message: String

    private let releasesURL = URL(string: "https://github.com/apple/container/releases")!

    var body: some View {
        ContentUnavailableView {
            Label("Container System Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if store.binaryAvailable {
                Button("Start System Service") {
                    Task { await store.startDaemon() }
                }
                .buttonStyle(.borderedProminent)
            } else if store.homebrewAvailable {
                Button {
                    Task { await store.installViaHomebrew() }
                } label: {
                    if store.installing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Install with Homebrew")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.installing)
            } else {
                Link("Download from GitHub", destination: releasesURL)
                    .buttonStyle(.borderedProminent)
            }
            Button("Retry") { Task { await store.refresh() } }
                .disabled(store.installing)
        }
    }
}
