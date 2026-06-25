//
//  RunOptions.swift
//  containerr
//
//  Builds the argument list for `container run`. The GUI always runs detached
//  (-d) since there's no attached terminal to take over.
//

import Foundation

struct RunOptions {
    var image: String = ""
    var name: String = ""
    /// host:container port mappings, e.g. "8080:80".
    var ports: [String] = []
    /// key=value environment entries.
    var env: [String] = []
    /// Bind-mount volume specs.
    var volumes: [String] = []
    /// Number of CPUs to allocate. We default to 2 (Apple's CLI defaults to 4,
    /// but CPU is far more dynamic than memory so a smaller default is fine).
    var cpus: Int = 2
    /// Memory allocation in MiB. Defaults to 1 GiB, matching Apple's CLI.
    var memoryMiB: Int = 1024
    var removeOnExit = false
    /// Optional command + args to override the image entrypoint.
    var command: String = ""

    var arguments: [String] {
        var args = ["run", "--detach"]
        if removeOnExit { args.append("--rm") }
        if !name.trimmed.isEmpty { args += ["--name", name.trimmed] }
        for p in ports.cleaned { args += ["--publish", p] }
        for e in env.cleaned { args += ["--env", e] }
        for v in volumes.cleaned { args += ["--volume", v] }
        args += ["--cpus", "\(cpus)"]
        args += ["--memory", "\(memoryMiB)M"]
        args.append(image.trimmed)
        // Split a freeform command line on whitespace for trailing args.
        args += command.trimmed.split(separator: " ").map(String.init)
        return args
    }

    /// Basic client-side validation; returns a user-facing reason if invalid.
    var validationError: String? {
        image.trimmed.isEmpty ? "An image reference is required." : nil
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension Array where Element == String {
    /// Drops blank entries and trims the rest.
    var cleaned: [String] {
        compactMap {
            let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    }
}
