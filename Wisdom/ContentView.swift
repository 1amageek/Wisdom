//
//  ContentView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @Environment(AppState.self) var appState: AppState
    
    @Environment(\.openURL) private var openURL: OpenURLAction
    
    @Environment(\.openWindow) private var openWindow: OpenWindowAction
    
    @State private var isFileTypeSelectionPresented = false
    
    @State private var isServerSettingsPresented = false
    
    @State var isServerRunning: Bool = false
    
    @State var isBuildInProgress: Bool = false
    
    @State private var isChatViewPresented: Bool = false
    
    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            FileSystemView(rootItem: appState.rootItem, selection: $state.selection) {
                Text("No directory loaded")
                
                Button {
                    appState.selectDirectory()
                } label: {
                    Text("Select Directory")
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Spacer()
      
                    Button {
                        Task {
                            do {
                                isBuildInProgress = true
                                try await appState.buildProject()
                                isBuildInProgress = false
                            } catch {
                                isBuildInProgress = false
                            }
                        }
                    } label: {
                        Image(systemName: isServerRunning ? "stop.fill" : "play.fill")
                            .padding(.horizontal, 6)
                    }
         
                    Button {
                        isServerSettingsPresented.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .padding(0)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        appState.selectDirectory()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderless)
                    Button {
                        isFileTypeSelectionPresented.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(8)
                .background(.regularMaterial)
            }
        } detail: {
            ContextView()
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            Task {
                                let isRunning = await appState.isServerRunning()
                                if isRunning {
                                    self.isServerRunning = false
                                    await appState.stopServer()
                                } else {
                                    self.isServerRunning = true
                                    await appState.startServer()
                                    let hostname = await self.appState.serverManager.hostname
                                    let port = await self.appState.serverManager.port
                                    self.openURL(URL(string: "http://\(hostname):\(port)/context")!)
                                }
                            }
                        } label: {
                            Image(systemName: isServerRunning ? "stop.fill" : "play.fill")
                                .padding(.horizontal, 6)
                        }
                        Button {
                            appState.copyToClipboard()
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        Button {
                            openWindow(id: "chat")
                        } label: {
                            Image(systemName: "message")
                        }
                    }
                }
        }
        .sheet(isPresented: $isFileTypeSelectionPresented) {
            FileTypeSelectionView()
        }
        .sheet(isPresented: $isServerSettingsPresented) {
            ServerSettingsView()
        }
    }
}

#Preview {
    ContentView()
}
