import SwiftUI

struct ContentView: View {
    
    @Environment(AppState.self) var appState: AppState
    @Environment(BuildManager.self) var buildManager: BuildManager
    @Environment(Agent.self) var agent: Agent
    
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.openWindow) private var openWindow: OpenWindowAction
    
    @State private var isFileTypeSelectionPresented = false
    @State private var isSettingsPresented = false
    @State private var isAgentMessageSheetPresented = false
    @State var isServerRunning: Bool = false
    @State var isBuildInProgress: Bool = false
    @State private var showBuildErrorAlert = false
    @State private var selectedCode: ImprovedCode?
    @State private var agentMessage: String = ""
    
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
                                if buildManager.isBuilding {
                                    buildManager.stop()
                                } else {
                                    try await buildManager.start()
                                }
                            } catch {
                                print(error)
                                showBuildErrorAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: buildManager.isBuilding ? "stop.fill" : "play.fill")
                            .padding(.horizontal, 6)
                    }
                    
                    Button {
                        isAgentMessageSheetPresented = true
                    } label: {
                        Image(systemName: appState.isAgentRunning ? "stop.circle" : "repeat")
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
            VSplitView {
                ContextView()
                    .frame(maxWidth: .infinity)
                LogView()
                    .frame(maxWidth: .infinity)
                    .frame(idealHeight: 120)
            }
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isSettingsPresented.toggle()
                    } label: {
                        Image(systemName: "gear")
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
