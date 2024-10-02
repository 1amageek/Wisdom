//
//  SideBar.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI
import FileSystemNavigator

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
                ]) { item, isHovered in
                    HStack {
                        Text(item.wrappedValue.name)
                        Spacer()
                        if isHovered {
                            Button {
                                copyContext(item: item.wrappedValue)
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(.borderless)
                        }
                        Toggle("", isOn: Binding(
                            get: { ContextManager.shared.isPathMonitored(item.wrappedValue.url.path) },
                            set: { newValue in
                                if !newValue {
                                    ContextManager.shared.insertExcludedPath(item.wrappedValue.url.path)
                                } else {
                                    ContextManager.shared.deleteExcludedPath(item.wrappedValue.url.path)
                                }
                            }
                        ))
                    }
                }
                .id(url)
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
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    appState.selectDirectory()
                } label: {
                    Image(systemName: "folder")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                .disabled(appState.rootItem == nil)
                Spacer()
            }
            .padding(8)
            .background(.regularMaterial)
        }
        .onChange(of: fileSystem.selection) { oldValue, newValue in
            appState.selection = newValue
        }
    }
    
    private func copyContext(item: FileItem) {
        Task {
            let context: String
            if item.isDirectory {
                context = ContextManager.shared.getDirectoryContext(item.url)
            } else {
                context = ContextManager.shared.getFileContext(for: item.url.path) ?? ""
            }
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(context, forType: .string)
            }
        }
    }
}

#Preview {
    SideBar()
}
