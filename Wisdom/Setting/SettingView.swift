//
//  SettingView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import SwiftUI

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Command Settings") {
                    CommandSettingView()
                }
                NavigationLink("Server Settings") {
                    ServerSettingView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400)
        .frame(minHeight: 200)
    }
}


#Preview {
    SettingView()
}
