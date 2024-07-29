//
//  MainView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI

struct MainView: View {
    
    @Environment(AppState.self) var appState: AppState
    
    @State var file: CodeFile?
    
    var body: some View {
        ZStack {
            if let file {
                CodeEditor(Binding(get: {
                    file
                }, set: { file in
                    self.file = file
                }))
                .id(file.id)
            } else {
                Text("No file selected")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: appState.selection) { oldValue, newValue in
            Task {
                if newValue.count == 1,
                   let item = newValue.first,
                   let file = loadFile(item)
                {
                    self.file = file
                }
            }
        }
    }
    
    func loadFile(_ item: FileItem) -> CodeFile? {
        guard !item.isDirectory else { return nil }
        do {
            let content = try String(contentsOf: item.url, encoding: .utf8)
            return CodeFile(url: item.url, content: content)
        } catch {
            print("Error loading file: \(error)")
            return nil
        }
    }
}

#Preview {
    MainView()
}
