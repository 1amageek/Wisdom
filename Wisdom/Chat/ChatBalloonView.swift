//
//  ChatBalloonView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import SwiftUI

struct ChatBalloonView: View {
    
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content[0].text)
                .padding(10)
                .background(message.isUser ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatBalloonView(message: .init(id: "id", content: [.init(text: "")], role: .model, timestamp: Date()))
}
