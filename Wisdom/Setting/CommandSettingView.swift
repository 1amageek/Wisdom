//
//  CommandSettingView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import SwiftUI


struct CommandSettingView: View {

    @Environment(BuildManager.self) var buildManager: BuildManager
    
    var body: some View {
        @Bindable var state = buildManager
        Form {
            Section(header: Text("Build Command")) {
                TextField("Enter build command", text: $state.buildCommand)
            }
        }
        .navigationTitle("Command Settings")
    }
}

#Preview {
    CommandSettingView()
}
