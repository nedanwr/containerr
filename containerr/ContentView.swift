//
//  ContentView.swift
//  containerr
//

import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var store = ContainerStore()
    @State private var section: SidebarSection = .containers
    @State private var showingRun = false
    @State private var showingPull = false
    /// Image reference to prefill the run wizard with ("Run from image").
    @State private var runImageReference: String?

    var body: some View {
        // Custom split: flat, opaque panes with a soft gray divider we control
        // (HSplitView forces a hard system divider line; NavigationSplitView floats).
        ResizableSplit {
            sidebar
        } detail: {
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Containerr")
        .toolbar { toolbar }
        .sheet(isPresented: $showingRun) {
            RunContainerView(store: store)
        }
        .sheet(item: $runImageReference) { reference in
            RunContainerView(store: store, prefillImage: reference)
        }
        .sheet(isPresented: $showingPull) {
            PullImageView(store: store)
        }
        .task { store.startPolling() }
        .onDisappear { store.stopPolling() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(SidebarSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            searchBar
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            switch section {
            case .containers: ContainerListView(store: store)
            case .images: ImageListView(store: store)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(section == .containers ? "Search containers" : "Search images",
                          text: $store.searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("sidebarSearchField")
                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            if section == .containers {
                Menu {
                    Picker("State", selection: $store.stateFilter) {
                        ForEach(ContainerStore.StateFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Image(systemName: store.stateFilter == .all
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Filter by state")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch section {
            case .containers:
                Button { showingRun = true } label: { Image(systemName: "plus") }
                    .help("Run a new container")
                    .accessibilityIdentifier("runContainerButton")
            case .images:
                Button { showingPull = true } label: { Image(systemName: "arrow.down.circle") }
                    .help("Pull an image")
                    .accessibilityIdentifier("pullImageButton")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { Task { await store.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
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
            switch section {
            case .containers: containerDetail
            case .images: imageDetail
            }
        }
    }

    @ViewBuilder
    private var containerDetail: some View {
        if let container = store.selected() {
            ContainerDetailView(store: store, container: container)
        } else {
            ContentUnavailableView("Select a Container", systemImage: "shippingbox",
                description: Text("Choose a container from the sidebar to see details."))
        }
    }

    @ViewBuilder
    private var imageDetail: some View {
        if let image = store.selectedImage() {
            ImageDetailView(store: store, image: image) { img in
                runImageReference = img.reference
            }
        } else {
            ContentUnavailableView("Select an Image", systemImage: "photo.stack",
                description: Text("Choose an image from the sidebar to see details."))
        }
    }
}

// Allows using a String reference directly with `.sheet(item:)`.
extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    ContentView()
}
