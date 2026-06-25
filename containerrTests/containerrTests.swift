//
//  containerrTests.swift
//  containerrTests
//

import Foundation
import Testing
@testable import containerr

// MARK: - Snapshot decoding

struct SnapshotDecodingTests {

    /// A trimmed but faithful copy of real `container list --format json` output.
    static let sampleJSON = """
    [
      {
        "id": "testweb",
        "configuration": {
          "id": "testweb",
          "image": { "reference": "docker.io/library/nginx:latest" },
          "platform": { "os": "linux", "architecture": "arm64" },
          "publishedPorts": [
            { "hostAddress": "0.0.0.0", "hostPort": 18080, "containerPort": 80, "proto": "tcp" }
          ],
          "labels": {},
          "creationDate": "2026-06-25T08:23:37Z"
        },
        "status": {
          "state": "running",
          "startedDate": "2026-06-25T08:23:38Z",
          "networks": [
            { "ipv4Address": "192.168.64.3/24", "hostname": "testweb", "network": "default" }
          ]
        }
      }
    ]
    """

    private func decode(_ json: String) throws -> [ContainerSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ContainerSnapshot].self, from: Data(json.utf8))
    }

    @Test func decodesCoreFields() throws {
        let snaps = try decode(Self.sampleJSON)
        #expect(snaps.count == 1)
        let c = try #require(snaps.first)
        #expect(c.id == "testweb")
        #expect(c.state == .running)
        #expect(c.image == "docker.io/library/nginx:latest")
        #expect(c.ipv4 == "192.168.64.3")          // CIDR suffix stripped
        #expect(c.publishedPorts.first?.hostPort == 18080)
        #expect(c.publishedPorts.first?.containerPort == 80)
    }

    @Test func unknownStateFallsBackToUnknown() throws {
        let json = Self.sampleJSON.replacingOccurrences(of: "\"running\"", with: "\"paused\"")
        let c = try #require(try decode(json).first)
        #expect(c.state == .unknown)
    }

    @Test func toleratesMissingOptionalSections() throws {
        // No networks, no published ports — must still decode cleanly.
        let json = """
        [{ "id": "bare", "configuration": { "id": "bare",
           "image": { "reference": "alpine" } },
           "status": { "state": "stopped" } }]
        """
        let c = try #require(try decode(json).first)
        #expect(c.ipv4 == nil)
        #expect(c.publishedPorts.isEmpty)
        #expect(c.state == .stopped)
    }
}

// MARK: - RunOptions argument building

struct RunOptionsTests {

    @Test func buildsDetachedRunWithAllFields() {
        var opts = RunOptions()
        opts.image = "nginx:latest"
        opts.name = "web"
        opts.ports = ["8080:80", ""]          // blank entry should be dropped
        opts.env = ["KEY=value"]
        opts.volumes = ["/host:/data"]
        opts.cpus = 3
        opts.memoryMiB = 2048
        opts.removeOnExit = true
        opts.command = "nginx -g daemon"

        let args = opts.arguments
        #expect(args.first == "run")
        #expect(args.contains("--detach"))
        #expect(args.contains("--rm"))
        #expect(adjacent(args, "--name", "web"))
        #expect(adjacent(args, "--publish", "8080:80"))
        #expect(!args.contains(""))           // blanks filtered out
        #expect(adjacent(args, "--env", "KEY=value"))
        #expect(adjacent(args, "--volume", "/host:/data"))
        #expect(adjacent(args, "--cpus", "3"))
        #expect(adjacent(args, "--memory", "2048M"))
        // Image precedes its trailing command args.
        let imageIdx = try! #require(args.firstIndex(of: "nginx:latest"))
        #expect(args[imageIdx...].contains("daemon"))
    }

    @Test func omitsRemoveFlagByDefault() {
        var opts = RunOptions()
        opts.image = "alpine"
        #expect(!opts.arguments.contains("--rm"))
    }

    @Test func requiresImage() {
        var opts = RunOptions()
        #expect(opts.validationError != nil)
        opts.image = "alpine"
        #expect(opts.validationError == nil)
    }

    /// Returns true if `value` immediately follows `flag` in the argument list.
    private func adjacent(_ args: [String], _ flag: String, _ value: String) -> Bool {
        for (i, a) in args.enumerated() where a == flag {
            if i + 1 < args.count && args[i + 1] == value { return true }
        }
        return false
    }
}

// MARK: - Resource policy

struct ResourcePolicyTests {

    @Test func defaultPolicyReservesHostResources() {
        let policy = ResourcePolicy(override: false)
        // Reserve is the larger of 6 GB or 25% of RAM, and is non-negative.
        #expect(policy.memoryReserveMiB >= 6144)
        #expect(policy.maxMemoryMiB >= 256)
        #expect(policy.maxCPUs >= 1)
    }

    @Test func overrideLiftsReserves() {
        let policy = ResourcePolicy(override: true)
        #expect(policy.memoryReserveMiB == 0)
        #expect(policy.maxMemoryMiB > ResourcePolicy(override: false).maxMemoryMiB
                || policy.maxMemoryMiB == ResourcePolicy(override: false).maxMemoryMiB)
        #expect(policy.maxCPUs >= ResourcePolicy(override: false).maxCPUs)
    }

    @Test func memoryStopsStayWithinCap() {
        let policy = ResourcePolicy(override: false)
        #expect(policy.memoryStops.allSatisfy { $0 <= policy.maxMemoryMiB })
        #expect(!policy.memoryStops.isEmpty)
    }

    @Test func nearestStopSnapsCorrectly() {
        let policy = ResourcePolicy(override: false)
        // 700 MB is closer to the 512 stop than the 1024 stop.
        #expect(policy.nearestStop(700) == 512)
    }

    @Test(arguments: [(512, "512 MB"), (1024, "1 GB"), (2048, "2 GB")])
    func formatsMemoryLabels(_ mib: Int, _ expected: String) {
        #expect(ResourcePolicy.formatMiB(mib) == expected)
    }
}
