//
//  WisdomApp.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI
import Observation

@main
struct WisdomApp: App {
    
    @State private var appState: AppState = AppState()
    @State private var contextManager: ContextManager = ContextManager.shared
    @State private var buildManager: BuildManager = BuildManager.shared
    @State private var directoryManager: DirectoryManager = DirectoryManager()
    @State private var agent: Agent = Agent.shared
    
    
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
                .environment(agent)
                .onAppear {
                    if let url = directoryManager.loadSavedDirectory() {
                        setDirectoryURL(url)
                    }
                }
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .onChange(of: appState.rootItem) { _, newValue in
            if let newRootItem = newValue {
                print("App: New root item set - \(newRootItem.name)")
                setDirectoryURL(newRootItem.url)
            } else {
                print("App: Root item cleared")
                buildManager.buildWorkingDirectory = nil
            }
        }
        .commands{
            CommandGroup(after: .newItem) {
                Button("Save") {
                    if let file = appState.selectedFile {
                        Task {
                            do {
                                try await appState.saveFile(file)
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        
        Window("Chat", id: "chat") {
            ChatNavigationView()
                .environment(appState)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentSize)
    }
    
    private func setDirectoryURL(_ url: URL) {
        appState.setURL(url)
        buildManager.buildWorkingDirectory = url
        Task {
            await appState.serverManager.setDelegate(appState)
            if await !appState.serverManager.isServerRunning() {
                try? await appState.serverManager.start()
            }
        }
    }
}
