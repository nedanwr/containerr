//
//  ContainerCLI.swift
//  containerr
//
//  Thin wrapper around Apple's `container` CLI. Shells out via Process and
//  decodes `--format json` output. All blocking work runs off the main actor.
//

import Foundation

enum CLIError: LocalizedError {
    case binaryNotFound
    case daemonDown
    case nonZero(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound: "The `container` CLI was not found."
        case .daemonDown: "The container system service isn't running."
        case .nonZero(let msg): msg
        }
    }
}

struct ContainerCLI {
    /// Common install locations, checked before falling back to PATH lookup.
    private static let candidatePaths = [
        "/usr/local/bin/container",
        "/opt/homebrew/bin/container",
    ]

    let binaryPath: String?

    init() {
        self.init(candidatePaths: Self.candidatePaths,
                  pathEnv: ProcessInfo.processInfo.environment["PATH"])
    }

    /// Testable initializer: resolves the binary over an injectable candidate
    /// list, then `$PATH`, using an injectable executable probe.
    init(candidatePaths: [String],
         pathEnv: String?,
         isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) {
        let pathDirs = (pathEnv ?? "").split(separator: ":").map { "\($0)/container" }
        binaryPath = (candidatePaths + pathDirs).first(where: isExecutable)
    }

    var isAvailable: Bool { binaryPath != nil }

    // MARK: - Core invocation

    @discardableResult
    func run(_ args: [String]) async throws -> Data {
        guard let binaryPath else { throw CLIError.binaryNotFound }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = args
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.terminationHandler = { proc in
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outData)
                } else {
                    let msg = String(decoding: errData, as: UTF8.self)
                    if msg.contains("XPC connection error") || msg.contains("system service") {
                        continuation.resume(throwing: CLIError.daemonDown)
                    } else {
                        continuation.resume(throwing: CLIError.nonZero(
                            msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Commands

    func list() async throws -> [ContainerSnapshot] {
        let data = try await run(["list", "--all", "--format", "json"])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ContainerSnapshot].self, from: data)
    }

    /// Creates and starts a detached container from `container run`.
    func create(_ options: RunOptions) async throws {
        try await run(options.arguments)
    }

    func start(id: String) async throws { try await run(["start", id]) }
    func stop(id: String) async throws { try await run(["stop", id]) }
    func delete(id: String) async throws { try await run(["delete", "--force", id]) }

    func logs(id: String, tail: Int = 200) async throws -> String {
        let data = try await run(["logs", "-n", "\(tail)", id])
        return String(decoding: data, as: UTF8.self)
    }

    func systemStart() async throws { try await run(["system", "start"]) }

    /// Opens an interactive shell in Terminal.app. We can't host a TTY inside
    /// our own Process, so we drop a `.command` script and let `open` route it
    /// to Terminal, which provides the interactive terminal.
    func openShell(id: String, shell: String = "/bin/sh") throws {
        guard let binaryPath else { throw CLIError.binaryNotFound }
        let script = """
        #!/bin/bash
        exec \(shellQuote(binaryPath)) exec -it \(shellQuote(id)) \(shellQuote(shell))
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("containerr-shell-\(id).command")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = [url.path]
        try open.run()
    }

    /// Wraps a value in single quotes for safe embedding in the shell script.
    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Images

    func images() async throws -> [ImageSummary] {
        let data = try await run(["image", "list", "--format", "json"])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ImageSummary].self, from: data)
    }

    func pullImage(reference: String) async throws { try await run(["image", "pull", reference]) }
    func deleteImage(reference: String) async throws { try await run(["image", "delete", reference]) }
}
