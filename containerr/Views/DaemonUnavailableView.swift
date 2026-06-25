//
//  DaemonUnavailableView.swift
//  containerr
//

import SwiftUI

struct DaemonUnavailableView: View {
    @Bindable var store: ContainerStore
    let message: String

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
            }
            Button("Retry") { Task { await store.refresh() } }
        }
    }
}
