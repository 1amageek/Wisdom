//
//  AgentMessageView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import SwiftUI

struct AgentMessageView: View {
    @Binding var message: String
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Enter a message for the Agent")
                .font(.headline)
            
            TextEditor(text: $message)
                .frame(height: 100)
                .border(Color.gray, width: 1)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Start Agent") {
                    onStart()
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
