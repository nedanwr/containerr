//
//  ContainerStore.swift
//  containerr
//
//  Observable view-model: holds container state, refreshes on a timer, and
//  exposes start/stop/delete actions.
//

import Foundation
import Observation

@MainActor
@Observable
final class ContainerStore {
    enum Phase: Equatable {
        case loading
        case ready
        case unavailable(String)
        case error(String)
    }

    private(set) var containers: [ContainerSnapshot] = []
    private(set) var images: [ImageSummary] = []
    private(set) var phase: Phase = .loading
    /// IDs with an action currently in flight, so rows can disable/spin.
    private(set) var busy: Set<String> = []
    /// True while a `brew install container` is in flight.
    private(set) var installing = false
    var selection: String?
    var imageSelection: String?

    // MARK: - Search & filtering

    enum StateFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
        var id: String { rawValue }
    }

    var searchText = ""
    var stateFilter: StateFilter = .all

    /// Containers matching the search text and state filter.
    var filteredContainers: [ContainerSnapshot] {
        Self.filter(containers, searchText: searchText, state: stateFilter)
    }

    /// Images matching the search text.
    var filteredImages: [ImageSummary] {
        Self.filter(images, searchText: searchText)
    }

    nonisolated static func filter(_ containers: [ContainerSnapshot],
                                   searchText: String,
                                   state: StateFilter) -> [ContainerSnapshot] {
        containers.filter { container in
            switch state {
            case .all: break
            case .running: guard container.state == .running else { return false }
            case .stopped: guard container.state != .running else { return false }
            }
            return matches(searchText, in: container.id, container.image)
        }
    }

    nonisolated static func filter(_ images: [ImageSummary],
                                   searchText: String) -> [ImageSummary] {
        images.filter { matches(searchText, in: $0.reference, $0.shortDigest) }
    }

    private nonisolated static func matches(_ query: String, in fields: String...) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return fields.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    private var cli = ContainerCLI()
    private let brew = Homebrew()
    private var pollTask: Task<Void, Never>?

    var binaryAvailable: Bool { cli.isAvailable }
    var homebrewAvailable: Bool { brew.isAvailable }

    func selected() -> ContainerSnapshot? {
        containers.first { $0.id == selection }
    }

    func selectedImage() -> ImageSummary? {
        images.first { $0.id == imageSelection }
    }

    // MARK: - Polling lifecycle

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard cli.isAvailable else {
            phase = .unavailable(brew.isAvailable
                ? "The `container` CLI isn't installed. Install it with Homebrew below."
                : "The `container` CLI isn't installed. Install Homebrew, or download it from github.com/apple/container.")
            return
        }
        do {
            containers = try await cli.list().sorted { $0.id < $1.id }
            images = try await cli.images().sorted { $0.reference < $1.reference }
            phase = .ready
        } catch CLIError.daemonDown {
            phase = .unavailable("The container system service isn't running.")
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Actions

    func startDaemon() async {
        do { try await cli.systemStart(); await refresh() }
        catch { phase = .error(error.localizedDescription) }
    }

    /// Installs the `container` formula via Homebrew, then re-detects the CLI
    /// and starts the system service.
    func installViaHomebrew() async {
        guard brew.isAvailable, !installing else { return }
        installing = true
        defer { installing = false }
        do {
            try await brew.installContainer()
            cli = ContainerCLI()  // re-detect now that the binary should exist
            if cli.isAvailable {
                try? await cli.systemStart()
            }
            await refresh()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Creates a container. Returns nil on success, or an error message to show
    /// in the wizard (keeps the sheet open so the user can fix and retry).
    func create(_ options: RunOptions) async -> String? {
        do {
            try await cli.create(options)
            selection = options.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : options.name
            await refresh()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Pulls an image by reference. Returns nil on success or an error message
    /// for the pull sheet (keeps it open so the user can fix and retry).
    func pull(_ reference: String) async -> String? {
        do {
            try await cli.pullImage(reference: reference)
            await refresh()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteImage(_ image: ImageSummary) async {
        await act(image.id) { try await self.cli.deleteImage(reference: image.reference) }
        if imageSelection == image.id { imageSelection = nil }
    }

    /// Opens an interactive shell for the container in Terminal.app.
    func openShell(_ id: String) {
        do { try cli.openShell(id: id) }
        catch { phase = .error(error.localizedDescription) }
    }

    func start(_ id: String) async { await act(id) { try await self.cli.start(id: id) } }
    func stop(_ id: String) async { await act(id) { try await self.cli.stop(id: id) } }
    func delete(_ id: String) async {
        await act(id) { try await self.cli.delete(id: id) }
        if selection == id { selection = nil }
    }

    private func act(_ id: String, _ work: @escaping () async throws -> Void) async {
        busy.insert(id)
        defer { busy.remove(id) }
        do { try await work(); await refresh() }
        catch { phase = .error(error.localizedDescription) }
    }
}
