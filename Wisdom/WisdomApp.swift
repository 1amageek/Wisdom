//
//  WisdomApp.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI

@main
struct WisdomApp: App {
    
    @State private var appState: AppState = AppState()
    @State private var buildManager: BuildManager = BuildManager()
    @State private var directoryManager: DirectoryManager = DirectoryManager()
    
    
    init() {
        let filteredArguments = CommandLine.arguments.filter { $0 != "-NSDocumentRevisionsDebugMode" }
        if filteredArguments.isEmpty {
            CommandLine.arguments = [CommandLine.arguments[0]]
        } else {
            CommandLine.arguments = filteredArguments
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(buildManager)
                .onAppear {
                    if let url = directoryManager.loadSavedDirectory() {
                        setDirectoryURL(url)
                    }
                }
        }
        .onChange(of: appState.rootItem) { _, newValue in
            if let newRootItem = newValue {
                print("App: New root item set - \(newRootItem.name)")
                setDirectoryURL(newRootItem.url)
            } else {
                print("App: Root item cleared")
                buildManager.buildWorkingDirectory = nil
            }
        }
        
        Window("Chat", id: "chat") {
            ChatView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
    }
    
    private func setDirectoryURL(_ url: URL) {
        appState.setURL(url)
        buildManager.buildWorkingDirectory = url
        Task {
            await appState.serverManager.setDelegate(appState, buildManager: buildManager)
            if await !appState.serverManager.isServerRunning() {
                try? await appState.serverManager.start()
            }
        }
    }
}
