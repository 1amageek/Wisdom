// Sources/FileSystemView/FileSystem.swift
import SwiftUI

@Observable
public final class FileSystem {
    
    public static let shared: FileSystem = FileSystem()
    
    public var fileItem: FileItem?
    
    public var selection: Set<FileItem> = []
    
    var showingDeleteConfirmation = false
    
    init() { }
    
    public func setURL(_ url: URL) {
        self.setFileItem(FileItem(url: url))
    }
    
    func setFileItem(_ fileItem: FileItem?) {
        self.fileItem = fileItem
    }
    
    func delete(item: FileItem) {
        deleteItems([item])
    }
    
    func deleteItems(_ items: Set<FileItem>) {
        let fileManager = FileManager.default
        for item in items {
            try? fileManager.removeItem(at: item.url)
        }
        fileItem?.loadFileItems()
    }
    
    func copy(item: FileItem, to destinationURL: URL) {
        let fileManager = FileManager.default
        let destination = destinationURL.appendingPathComponent(item.name)
        try? fileManager.copyItem(at: item.url, to: destination)
        fileItem?.loadFileItems()
    }
    
    func move(item: FileItem, to destinationURL: URL) {
        let fileManager = FileManager.default
        let destination = destinationURL.appendingPathComponent(item.name)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination) // 移動先が存在する場合は削除
        }
        try? fileManager.moveItem(at: item.url, to: destination)
        fileItem?.loadFileItems() // Update the file items after moving
    }
    
    func rename(item: FileItem, newName: String) {
        let fileManager = FileManager.default
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try? fileManager.moveItem(at: item.url, to: destination)
        fileItem?.loadFileItems()
    }
}

extension FileSystem {
    
    @ViewBuilder
    public func view<Content: View>(_ sections: [FileItemSection] = [], @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            if let fileItem = self.fileItem {
                FileSystemView(sections: sections)
//                FileSystemView(sections: [.init(name: "Projects", item: fileItem)] + sections)
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    @State var fileSystem = FileSystem.shared
    
    return fileSystem.view {
        Text("Content")
    }
}
