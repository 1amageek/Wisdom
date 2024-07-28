//
//  ChatView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import SwiftUI

struct ChatNavigationView: View {
    @State var viewModel: ChatViewModel = ChatViewModel()
    @State private var selectedAction: AgentAction?
    @State private var isInspectorPresented = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedThreadID) {
                ForEach(viewModel.threads) { thread in
                    Text(thread.name)
                        .tag(thread.id)
                }
            }
            .navigationTitle("Threads")
            .navigationSplitViewColumnWidth(ideal: 240)
            .toolbar {
                Button {
                    self.viewModel.addNewThread(name: "new message")
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        } detail: {
            ZStack {
                if viewModel.selectedThreadID == nil {
                    Text("No messages")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    HSplitView {
                        ChatView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        AgentActionView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Prompt")
        }
        .frame(minWidth: 640, minHeight: 600)
        .environment(viewModel)
    }
}

#Preview {
    ChatView()
}
