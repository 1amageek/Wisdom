//
//  FileItemView.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import SwiftUI

struct FileItemView: View {
    let item: FileItem
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundColor(item.isDirectory ? .blue : .gray)
            Text(item.name)
                .lineLimit(1)
            Spacer()
            if isHovered {
                Button(action: copyContext) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered in
            self.isHovered = isHovered
        }
    }
    
    private func copyContext() {
        Task {
            let context: String
            if item.isDirectory {
                context = ContextManager.shared.getDirectoryContext(item.url)
            } else {
                context = ContextManager.shared.getFileContext(for: item.url.path) ?? ""
            }
            
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(context, forType: .string)
            }
        }
    }
}
