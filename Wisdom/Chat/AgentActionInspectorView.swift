//
//  AgentActionInspectorView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import SwiftUI

struct AgentActionInspectorView: View {
    let action: AgentAction?
    
    @Environment(AppState.self) private var appState
    
    @State private var showingSaveAlert = false
    @State private var saveError: Error?
    
    var body: some View {
        if let action = action {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(action.url.lastPathComponent)
                        .font(.headline)
                    
                    Text("Action: \(action.actionType.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let content = action.content {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action.actionType.rawValue) {
                    Task {
                        await performAction(action)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .alert("Action Result", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = saveError {
                    Text("Failed to perform action: \(error.localizedDescription)")
                } else {
                    Text("Action performed successfully!")
                }
            }
        } else {
            Text("No action selected")
                .foregroundColor(.secondary)
        }
    }
    
    private func performAction(_ action: AgentAction) async {
        do {
            switch action.actionType {
            case .create, .update:
                if let content = action.content {
                    try await appState.saveFile(url: action.url, content: content)
                }
            case .delete:
                try await appState.deleteFile(at: action.url)
                break
            }
            showingSaveAlert = true
            saveError = nil
        } catch {
            showingSaveAlert = true
            saveError = error
        }
    }
}

#Preview {
    AgentActionInspectorView(action: AgentAction(id: "preview", url: URL(string: "/")!, actionType: .create, content: "Sample content"))
        .environment(AppState())
}
