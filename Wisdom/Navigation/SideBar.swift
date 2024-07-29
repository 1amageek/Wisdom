//
//  SideBar.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI



struct SideBar: View {
    
    @Environment(AppState.self) var appState: AppState
    @Environment(BuildManager.self) var buildManager: BuildManager
    @Environment(Agent.self) var agent: Agent
    @State var fileSystemSelection: Set<FileItem> = []
    @State var requirementsSelection: Set<FileItem> = []
    
    var body: some View {
        @Bindable var state = appState
        @Bindable var manager = buildManager
        VStack(spacing: 4) {
            Picker("", selection: $state.selectedNavigation) {
                Image(systemName: "folder.fill")
                    .tag(SidebarNavigation.fileSystem)
                Image(systemName: "note.text")
                    .tag(SidebarNavigation.requirements)
            }
            .pickerStyle(.segmented)
            
            switch appState.selectedNavigation {
            case .fileSystem:
                FileSystemView(rootItem: appState.rootItem, selection: $fileSystemSelection) {
                    Text("No directory loaded")
                    
                    Button {
                        appState.selectDirectory()
                    } label: {
                        Text("Select Directory")
                    }
                }
            case .requirements:
                RequirementsView(rootItem: appState.rootItem, selection: $requirementsSelection) {
                    Text("No directory loaded")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 4)
        .onChange(of: fileSystemSelection) { oldValue, newValue in
            appState.selection = newValue
        }
        .onChange(of: requirementsSelection) { oldValue, newValue in
            appState.selection = newValue
        }
    }
}

#Preview {
    SideBar()
}
