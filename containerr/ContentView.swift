//
//  ContentView.swift
//  containerr
//

import SwiftUI

struct ContentView: View {
    @State private var store = ContainerStore()
    @State private var showingRun = false

    var body: some View {
        // Custom split: flat, opaque panes with a soft gray divider we control
        // (HSplitView forces a hard system divider line; NavigationSplitView floats).
        ResizableSplit {
            ContainerListView(store: store)
        } detail: {
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Containerr")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingRun = true } label: {
                    Image(systemName: "plus")
                }
                .help("Run a new container")
                .accessibilityIdentifier("runContainerButton")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .sheet(isPresented: $showingRun) {
            RunContainerView(store: store)
        }
        .task { store.startPolling() }
        .onDisappear { store.stopPolling() }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.phase {
        case .unavailable(let msg):
            DaemonUnavailableView(store: store, message: msg)
        case .error(let msg):
            ContentUnavailableView("Something Went Wrong", systemImage: "xmark.octagon",
                description: Text(msg))
        default:
            if let container = store.selected() {
                ContainerDetailView(store: store, container: container)
            } else {
                ContentUnavailableView("Select a Container", systemImage: "shippingbox",
                    description: Text("Choose a container from the sidebar to see details."))
            }
        }
    }
}

#Preview {
    ContentView()
}
