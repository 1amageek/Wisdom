//
//  FullContextView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/08/03.
//

import SwiftUI

struct FullContextView: View {
    
    @Environment(AppState.self) var appState: AppState
    @State private var contextLines: [String] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(contextLines.indices, id: \.self) { index in
                    Text(contextLines[index])
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .onAppear {
            loadFullContext()
        }
    }
    
    private func loadFullContext() {
        Task {
            let fullContext = ContextManager.shared.getFullContext()
            await MainActor.run {
                contextLines = fullContext.components(separatedBy: .newlines)
            }
        }
    }
}

#Preview {
    FullContextView()
}
