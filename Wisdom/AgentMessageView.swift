//
//  AgentMessageView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import SwiftUI

struct AgentMessageView: View {
    @Binding var message: String
    @State private var continueOnSuccess: Bool = false
    @State private var agentOption: AgentOption
    let onStart: (AgentOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(message: Binding<String>, onStart: @escaping (AgentOption) -> Void) {
        self._message = message
        self.onStart = onStart
        self._agentOption = State(initialValue: AgentOption(continueOnSuccess: false))
    }
    
    var body: some View {
        VStack {
            Text("Enter a message for the Agent")
                .font(.headline)
            
            TextEditor(text: $message)
                .frame(height: 100)
                .border(Color.gray, width: 1)
            
            Toggle("Continue on Success", isOn: $continueOnSuccess)
                .padding(.vertical)
                .onChange(of: continueOnSuccess) { _, newValue in
                    agentOption.continueOnSuccess = newValue
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Start Agent") {
                    onStart(agentOption)
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
