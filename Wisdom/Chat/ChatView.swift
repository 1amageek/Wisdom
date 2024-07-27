//
//  ChatView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import SwiftUI

struct ChatView: View {
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
                    ScrollView {
                        LazyVStack {
                            ForEach(viewModel.messages) { message in
                                ChatBalloonView(message: message, selectedAction: $selectedAction)
                            }
                        }
                        .padding()
                    }
                    .safeAreaInset(edge: .bottom) {
                        HStack(alignment: .bottom) {
                            TextEditor(text: $viewModel.inputMessage.animation())
                                .padding(4)
                                .frame(minHeight: 24)
                                .fixedSize(horizontal: false, vertical: true)
                                .scrollContentBackground(.hidden)
                                .background(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12.0))
                                .font(.system(size: 12))
                            
                            if !viewModel.inputMessage.isEmpty {
                                Button(action: viewModel.sendMessage) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .disabled(viewModel.inputMessage.isEmpty || viewModel.isLoading)
                                .keyboardShortcut(.return, modifiers: .command)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("Prompt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { isInspectorPresented.toggle() }) {
                        Image(systemName: "sidebar.right")
                    }
                }
            }
            .inspector(isPresented: $isInspectorPresented) {
                AgentActionInspectorView(action: selectedAction)
            }
        }
        .frame(minWidth: 640, minHeight: 600)
        .environment(viewModel)
    }
}

#Preview {
    ChatView()
}
