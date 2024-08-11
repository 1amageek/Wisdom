//
//  SideBar.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI
import FileSystemView

struct SideBar: View {
    
    @Environment(AppState.self) var appState: AppState
    @Environment(FileSystem.self) var fileSystem: FileSystem
    @Environment(BuildManager.self) var buildManager: BuildManager
    @Environment(Agent.self) var agent: Agent
    
    var body: some View {
        @Bindable var state = appState
        @Bindable var manager = buildManager
        VStack(spacing: 4) {
            
            if let url = appState.rootItem?.url {
                let wisdomURL = url.appendingPathComponent(".wisdom")
                fileSystem.view([
                    .init(name: "Projects", item: .init(url: url)),
                    .init(name: "Requirements", item: .init(url: wisdomURL))
                ]) {
                    EmptyView()
                }
            } else {
                VStack {
                    Text("No directory loaded")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        appState.selectDirectory()
                    } label: {
                        Text("Select Directory")
                    }
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: fileSystem.selection) { oldValue, newValue in
            appState.selection = newValue
        }
    }
}

#Preview {
    SideBar()
}
