//
//  ResourcePolicy.swift
//  containerr
//
//  Computes how much of the host's CPU/memory a container may claim. By default
//  we hold cores and RAM back for macOS; an advanced override (see Settings)
//  lifts those reserves for users who know what they're doing.
//

import Foundation

struct ResourcePolicy {
    /// When true, the host reserves are lifted and the full machine is offered.
    let override: Bool

    private let totalCores = ProcessInfo.processInfo.activeProcessorCount
    private let totalMemoryMiB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))

    /// Cores kept strictly for macOS under the default policy.
    static let cpuReserve = 4

    var maxCPUs: Int {
        override ? totalCores : max(1, totalCores - Self.cpuReserve)
    }

    /// Memory held back for macOS. Memory is allocated in full (no dynamic
    /// scaling), so the default reserve is the larger of 6 GB or 25% of RAM.
    var memoryReserveMiB: Int {
        override ? 0 : max(6144, totalMemoryMiB / 4)
    }

    var maxMemoryMiB: Int {
        max(256, totalMemoryMiB - memoryReserveMiB)
    }

    /// Standard slider stops, capped to what's available under this policy.
    var memoryStops: [Int] {
        let all = [256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]
        let usable = all.filter { $0 <= maxMemoryMiB }
        return usable.isEmpty ? [256] : usable
    }

    /// Index of the stop at or just below `mib` (for restoring slider position).
    func stopIndex(for mib: Int) -> Int {
        memoryStops.lastIndex { $0 <= mib } ?? 0
    }

    func nearestStop(_ mib: Int) -> Int {
        memoryStops.min { abs($0 - mib) < abs($1 - mib) } ?? memoryStops[0]
    }

    static func formatMiB(_ mib: Int) -> String {
        mib >= 1024 && mib % 1024 == 0 ? "\(mib / 1024) GB" : "\(mib) MB"
    }
}

/// Shared UserDefaults key for the advanced override toggle.
enum SettingsKey {
    static let overrideResourceLimits = "overrideResourceLimits"
}
