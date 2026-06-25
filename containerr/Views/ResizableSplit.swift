//
//  ResizableSplit.swift
//  containerr
//
//  A minimal two-pane horizontal split with a draggable divider whose color
//  we control — unlike HSplitView, which forces a hard system divider line.
//

import SwiftUI

struct ResizableSplit<Sidebar: View, Detail: View>: View {
    @AppStorage("sidebarWidth") private var width: Double = 260
    @State private var dragStartWidth: Double?
    let minWidth: Double
    let maxWidth: Double
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    init(minWidth: Double = 220, maxWidth: Double = 360,
         @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: width)
                .frame(maxHeight: .infinity)

            divider

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                // Wider invisible hit area so the 1pt line is easy to grab.
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                let start = dragStartWidth ?? width
                                dragStartWidth = start
                                width = min(max(start + value.translation.width, minWidth), maxWidth)
                            }
                            .onEnded { _ in dragStartWidth = nil }
                    )
            }
    }
}
