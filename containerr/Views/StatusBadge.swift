//
//  StatusBadge.swift
//  containerr
//

import SwiftUI

extension RuntimeState {
    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .secondary
        case .stopping: .orange
        case .unknown: .yellow
        }
    }
    var label: String { rawValue.capitalized }
}

/// Small colored dot used in list rows.
struct StatusDot: View {
    let state: RuntimeState
    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 8, height: 8)
    }
}

/// Pill badge used in the detail header.
struct StatusBadge: View {
    let state: RuntimeState
    var body: some View {
        HStack(spacing: 5) {
            StatusDot(state: state)
            Text(state.label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(state.color.opacity(0.15), in: Capsule())
        .foregroundStyle(state.color == .secondary ? .secondary : state.color)
    }
}
