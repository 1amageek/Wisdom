//
//  ChatViewModel.swift
//  Xpackage
//
//  Created by Norikazu Muramoto on 2024/07/19.
//


import SwiftUI
import Observation

@Observable
class ChatViewModel {
    
    var threads: [ChatThread] = []
    var messages: [ChatMessage] = []
    var inputMessage: String = ""
    var isLoading: Bool = false
    var selectedThreadID: String?
    
    func addNewThread(name: String) {
        let newThread = ChatThread(id: UUID().uuidString, name: name, createdAt: Date(), updatedAt: Date())
        threads.append(newThread)
        selectedThreadID = newThread.id
    }
    
    func selectThread(_ threadID: String) {
        selectedThreadID = threadID
        // ここでスレッドに応じたメッセージの読み込みを行う
        // 現在は簡略化のため、メッセージをクリアするだけにしています
        messages.removeAll()
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
                let response = try await Functions.shared.requirements(
                    userID: "testUser",
                    packageID: "testPackage",
                    threadID: threadID,
                    message: sentMessage
                )                            
                await MainActor.run {
                    messages.append(response)
                    isLoading = false
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
