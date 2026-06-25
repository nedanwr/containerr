//
//  SettingsView.swift
//  containerr
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.overrideResourceLimits) private var override = false
    @State private var confirmingEnable = false

    var body: some View {
        Form {
            Section {
                Toggle("Allow overriding host reserves", isOn: Binding(
                    get: { override },
                    set: { newValue in
                        // Require explicit confirmation to turn the override on;
                        // turning it back off is always allowed.
                        if newValue { confirmingEnable = true } else { override = false }
                    }))
            } header: {
                Text("Advanced")
            } footer: {
                Text("By default, containerr keeps cores and memory free for macOS. "
                   + "Overriding lets containers claim the entire machine, which can "
                   + "freeze or destabilize your Mac. Only enable this if you understand "
                   + "the consequences.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 220)
        .alert("Override host reserves?", isPresented: $confirmingEnable) {
            Button("Cancel", role: .cancel) { }
            Button("Enable", role: .destructive) { override = true }
        } message: {
            Text("Containers will be able to use all of your Mac's CPU and memory. "
               + "This can make macOS unresponsive. Continue only if you know what you're doing.")
        }
    }
}

#Preview {
    SettingsView()
}
