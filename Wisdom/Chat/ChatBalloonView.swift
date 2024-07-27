//
//  ChatBalloonView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import SwiftUI

struct ChatBalloonView: View {
    @Environment(ChatViewModel.self) var viewModel: ChatViewModel
    
    let message: ChatMessage
    
    @Binding var selectedAction: AgentAction?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text(message.content[0].text)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.isUser ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                if let codes = message.content[0].codes {
                    ForEach(codes) { code in
                        VStack(alignment: .leading) {
                            Text(code.URL.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(codeName(for: code.URL))
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAction = actionContent(for: code.id)
                                }
                        }
                    }
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func codeName(for url: URL) -> String {
        return "\(url.lastPathComponent)"
    }
    
    private func actionContent(for id: String) -> AgentAction? {
        return viewModel.agentActions.first(where: { $0.id == id })
    }
}

#Preview {
    ChatBalloonView(message: .init(id: "id", content: [.init(text: "")], role: .model, timestamp: Date()), selectedAction: .constant(nil))
        .environment(ChatViewModel())
}
