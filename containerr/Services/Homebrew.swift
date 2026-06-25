//
//  Homebrew.swift
//  containerr
//
//  Detects a local Homebrew install and can install the `container` formula
//  on the user's behalf. GUI apps launched from Finder don't inherit a shell
//  `PATH`, so we look in the known Homebrew prefixes directly.
//

import Foundation

struct Homebrew {
    /// Standard Homebrew binary locations: Apple Silicon then Intel.
    private static let candidatePaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew",
    ]

    let binaryPath: String?

    init() {
        self.init(candidatePaths: Self.candidatePaths)
    }

    /// Testable initializer: detection over an injectable path list and probe.
    init(candidatePaths: [String],
         isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) {
        binaryPath = candidatePaths.first(where: isExecutable)
    }

    var isAvailable: Bool { binaryPath != nil }

    /// Runs `brew install container`, streaming nothing but capturing combined
    /// output so failures carry a useful message. Throws `CLIError.nonZero` on
    /// a non-zero exit.
    func installContainer() async throws {
        guard let binaryPath else { throw CLIError.binaryNotFound }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = ["install", "container"]
            // Keep Homebrew non-interactive and quiet about analytics/auto-update.
            var env = ProcessInfo.processInfo.environment
            env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            env["HOMEBREW_NO_ANALYTICS"] = "1"
            env["NONINTERACTIVE"] = "1"
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let msg = String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: CLIError.nonZero(
                        msg.isEmpty ? "brew install container failed." : msg))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
