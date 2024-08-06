import SwiftUI

struct ContentView: View {
    
    
    @Environment(AppState.self) var appState: AppState
    @Environment(BuildManager.self) var buildManager: BuildManager
    @Environment(Agent.self) var agent: Agent
    
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.openWindow) private var openWindow: OpenWindowAction
    
    @State private var isSettingsPresented = false
    @State private var isAgentMessageSheetPresented = false
    
    @State var isBuildInProgress: Bool = false
    @State private var showBuildErrorAlert = false
    @State private var selectedCode: ImprovedCode?
    @State private var agentMessage: String = ""
    
    
    var body: some View {
        @Bindable var state = appState
        @Bindable var manager = buildManager
        NavigationSplitView {
            SideBar()
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Spacer()
                        
                        if !agent.isRunning {
                            Button {
                                Task {
                                    if buildManager.isBuilding {
                                        buildManager.stop()
                                    } else {
                                        await buildManager.start()
                                    }
                                }
                            } label: {
                                Image(systemName: buildManager.isBuilding ? "stop.fill" : "play.fill")
                                    .padding(.horizontal, 6)
                            }
                            .keyboardShortcut("b", modifiers: .command)
                        }
                        
                        Button {
                            if agent.isRunning {
                                agent.stop()
                            } else {
                                Task {
                                    isAgentMessageSheetPresented = true
                                }
                            }
                        } label: {
                            Image(systemName: agent.isRunning ? "stop.fill" : "forward.fill")
                                .padding(.horizontal, 4)
                        }
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
                .padding(0)
        } detail: {
            VSplitView {
                MainView()
                    .frame(maxWidth: .infinity)
                LogView()
                    .frame(maxWidth: .infinity)
                    .frame(idealHeight: 120)
            }
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    BuildStatusView()
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Spacer()
                    Button {
                        isSettingsPresented.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                    Button {
                        appState.isShowingFullContext.toggle()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(ContextManager.shared.getFullContext(), forType: .string)
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
        .sheet(isPresented: $isSettingsPresented) {
            SettingView()
        }
        .sheet(isPresented: $isAgentMessageSheetPresented) {
            AgentMessageView(message: $agentMessage) { option in
                Task {
                    await appState.startAgent(with: agentMessage, option: option)
                }
            }
        }
        .alert("Build Failed", isPresented: $showBuildErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The build process failed. Please check the log for more details.")
        }
        .alert("Move to Trash", isPresented: $state.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                appState.moveSelectedFilesToTrash()
            }
        } message: {
            let selectedFiles = appState.selection.filter { !$0.isDirectory }
            if selectedFiles.count == 1 {
                Text("Do you want to move '\(selectedFiles.first!.name)' to the Trash?")
            } else {
                Text("Do you want to move \(selectedFiles.count) items to the Trash?")
            }
        }
    }
}
