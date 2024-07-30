import SwiftUI

struct ContentView: View {
    
    
    @Environment(AppState.self) var appState: AppState
    @Environment(BuildManager.self) var buildManager: BuildManager
    @Environment(Agent.self) var agent: Agent
    
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.openWindow) private var openWindow: OpenWindowAction
        
    @State private var isSettingsPresented = false
    @State private var isAgentMessageSheetPresented = false
    @State var isServerRunning: Bool = false
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
                        
                        if !appState.isAgentRunning {
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
                        }
                        
                        Button {
                            withAnimation {
                                if !isAgentMessageSheetPresented {
                                    isAgentMessageSheetPresented = true
                                } else {
                                    agent.stop()
                                    isAgentMessageSheetPresented = false
                                }
                            }
                        } label: {
                            Image(systemName: appState.isAgentRunning ? "stop.fill" : "forward.fill")
                                .padding(.horizontal, 4)
                        }
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
            AgentMessageView(message: $agentMessage, onStart: startAgent)
        }
        .alert("Build Failed", isPresented: $showBuildErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The build process failed. Please check the log for more details.")
        }
    }
    
    private func startAgent() {
        Task {
            await appState.startAgent(with: agentMessage, agent: agent, buildManager: buildManager)
        }
    }
}
