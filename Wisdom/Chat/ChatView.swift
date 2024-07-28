//
//  ChatView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import SwiftUI

struct ChatView: View {
    
    @Environment(ChatViewModel.self) var viewModel: ChatViewModel
    
    var body: some View {
        @Bindable var state = viewModel
        ScrollView {
            LazyVStack {
                ForEach(viewModel.messages) { message in
                    ChatBalloonView(message: message)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom) {
                TextEditor(text: $state.inputMessage.animation())
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

#Preview {
    ChatView()
}
