//
//  ImageSummary.swift
//  containerr
//
//  Decodes `container image list --format json`. Defensive like
//  ContainerSnapshot — only the fields the UI needs, everything optional.
//

import Foundation

struct ImageSummary: Codable, Identifiable, Hashable {
    let id: String                       // image digest
    let configuration: Configuration
    let variants: [Variant]?

    /// Repository reference, e.g. "docker.io/library/nginx:latest".
    var reference: String { configuration.name }
    var shortDigest: String { String(id.replacingOccurrences(of: "sha256:", with: "").prefix(12)) }
    /// Total on-disk size across platform variants, in bytes.
    var sizeBytes: Int { (variants ?? []).reduce(0) { $0 + ($1.size ?? 0) } }
    var platforms: [String] {
        (variants ?? []).compactMap { $0.platform }.map { "\($0.os ?? "?")/\($0.architecture ?? "?")" }
    }

    struct Configuration: Codable, Hashable {
        let name: String
        let creationDate: Date?
    }

    struct Variant: Codable, Hashable {
        let size: Int?
        let platform: Platform?

        struct Platform: Codable, Hashable {
            let architecture: String?
            let os: String?
        }
    }
}
