//
//  WisdomApp.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI

@main
struct WisdomApp: App {

    @State var appState: AppState = AppState()
    
    init() {    
        let filteredArguments = CommandLine.arguments.filter { $0 != "-NSDocumentRevisionsDebugMode" }    
        if filteredArguments.isEmpty {
            CommandLine.arguments = [CommandLine.arguments[0]]
        } else {
            CommandLine.arguments = filteredArguments
        }
    }

    var body: some Scene {
        Group {
            WindowGroup {
                ContentView()
                    .onAppear {
                        Task {
                            await appState.serverManager.setDelegate(appState)
                        }
                    }
            }
            WindowGroup(id: "chat") {
                ChatView()
            }
            .windowResizability(.contentSize)
        }
        .environment(appState)

    }
}
