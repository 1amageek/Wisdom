//
//  ContextView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI

struct ContextView: View {
    
    @Environment(AppState.self) var appState: AppState
    
    @State var context: String = ""
    
    var body: some View {
        ZStack {
            if appState.contextManager!.isLoading {
                ProgressView("Loading context...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ScrollView {
                    Text(context)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding()
                }
            }
        }
        .onChange(of: appState.selection) { oldValue, newValue in
            Task {
                self.context = await appState.contextManager?.getSelectedContext(for: newValue) ?? ""
            }
        }
    }
}

extension String {
    func getAttributedString() -> AttributedString {
        do {
            let attributedString = try AttributedString(markdown: self)
            return attributedString
        } catch {
            print("Couldn't parse: \(error)")
        }
        return AttributedString("Error parsing markdown")
    }
}

#Preview {
    ContextView()
}
