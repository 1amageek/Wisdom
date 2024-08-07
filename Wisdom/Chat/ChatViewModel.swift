//
//  ChatViewModel.swift
//  Xpackage
//
//  Created by Norikazu Muramoto on 2024/07/19.
//


import SwiftUI
import Observation

enum ChatType {
    case requirements
    case implementation
}

@Observable
class ChatViewModel {
        
    var type: ChatType = .requirements
    var threads: [ChatThread] = []
    var messages: [ChatMessage] = []
    var agentActions: [AgentFileOperation] = []
    var selectedAction: AgentFileOperation?
    var inputMessage: String = ""
    var isLoading: Bool = false
    var selectedThreadID: String? {
        didSet {
            messages.removeAll()
        }
    }
    
    func addNewThread(name: String) {
        let newThread = ChatThread(id: UUID().uuidString, name: name, createdAt: Date(), updatedAt: Date())
        threads.append(newThread)
        selectedThreadID = newThread.id
    }
    
    func sendMessage() {
        guard let threadID = selectedThreadID else { return }
        guard !inputMessage.isEmpty else { return }
        
        isLoading = true
        
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            content: [ChatMessage.Content(text: inputMessage)],
            role: .user,
            timestamp: Date()
        )
        messages.append(userMessage)
        let sentMessage = inputMessage
        inputMessage = ""
        
        Task {
            do {
                switch self.type {
                case .implementation:
                    let (response, actions) = try await Functions.shared.message(
                        userID: "testUser",
                        packageID: "testPackage",
                        threadID: threadID,
                        message: sentMessage,
                        requirementsAndSpecification: RequirementsManager.shared.context(),
                        sources: ContextManager.shared.getFullContext(),
                        errors: BuildManager.shared.errors()
                    )
                    await MainActor.run {
                        self.agentActions.append(contentsOf: actions)
                        self.messages.append(response)
                        isLoading = false
                    }
                case .requirements:
                    let (response, actions) = try await Functions.shared.requirements(
                        userID: "testUser",
                        packageID: "testPackage",
                        threadID: threadID,
                        message: sentMessage
                    )
                    await MainActor.run {
                        self.agentActions.append(contentsOf: actions)
                        self.messages.append(response)
                        isLoading = false
                    }
                }

            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        id: UUID().uuidString,
                        content: [ChatMessage.Content(text: "Error: \(error.localizedDescription)")],
                        role: .model,
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}
