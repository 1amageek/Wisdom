//
//  SettingView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import SwiftUI

struct SettingView: View {
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
        }
    }
}

#Preview {
    SettingView()
}
