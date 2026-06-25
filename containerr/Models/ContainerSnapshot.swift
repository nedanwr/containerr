//
//  ContainerSnapshot.swift
//  containerr
//
//  Decodes the JSON emitted by `container list --all --format json`.
//  Modeled defensively: only the fields the UI needs, everything else optional,
//  so unknown/extra keys never break decoding.
//

import Foundation

struct ContainerSnapshot: Codable, Identifiable, Hashable {
    let id: String
    let configuration: Configuration
    let status: Status

    var image: String { configuration.image.reference }
    var state: RuntimeState { status.state }
    var ipv4: String? {
        status.networks?.first?.ipv4Address?.components(separatedBy: "/").first
    }
    var publishedPorts: [Configuration.Port] { configuration.publishedPorts ?? [] }

    struct Configuration: Codable, Hashable {
        let id: String
        let image: Image
        let platform: Platform?
        let publishedPorts: [Port]?
        let labels: [String: String]?
        let creationDate: Date?

        struct Image: Codable, Hashable { let reference: String }
        struct Platform: Codable, Hashable {
            let os: String?
            let architecture: String?
        }
        struct Port: Codable, Hashable, Identifiable {
            let hostAddress: String?
            let hostPort: Int
            let containerPort: Int
            let proto: String?
            var id: String { "\(hostPort)->\(containerPort)/\(proto ?? "")" }
        }
    }

    struct Status: Codable, Hashable {
        let state: RuntimeState
        let startedDate: Date?
        let networks: [Network]?

        struct Network: Codable, Hashable {
            let ipv4Address: String?
            let hostname: String?
            let network: String?
        }
    }
}

enum RuntimeState: String, Codable, Hashable {
    case unknown, stopped, running, stopping

    // Tolerate any future/unknown state string without failing decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RuntimeState(rawValue: raw) ?? .unknown
    }
}
