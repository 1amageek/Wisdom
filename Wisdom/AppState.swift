//
//  AppState.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import Foundation
import AppKit

@Observable
class AppState {
    
    var rootItem: FileItem?
    var selection: Set<FileItem> = []
    var availableFileTypes: [String] = []
    var selectedFileTypes: [String] = ["swift"]
    var contextManager: ContextManager?
    var serverManager: ServerManager = ServerManager()
    
    var context: String { self.contextManager?.getFullContext() ?? "" }
    
    var files: [CodeFile] { self.contextManager?.files ?? [] }
    
    private var directoryManager = DirectoryManager()
    
    func setURL(_ url: URL) {
        do {
            let resolvedURL = try directoryManager.setDirectory(url)
            self.rootItem = FileItem(url: resolvedURL)
            self.contextManager = ContextManager(rootURL: resolvedURL, config: ContextManager.Configuration(
                maxDepth: 5,
                excludedDirectories: ["Pods", ".git"],
                maxFileSize: 1_000_000,
                debounceInterval: 0.5,
                monitoredFileTypes: selectedFileTypes
            ))
            
            UserDefaults.standard.set(resolvedURL.path, forKey: "LastOpenedDirectory")
             
            Task {
                await loadAvailableFileTypes(resolvedURL)
            }
            
            print("Directory set successfully: \(resolvedURL.path)")
        } catch {
            print("Error setting URL: \(error.localizedDescription)")
        }
    }
    
    func saveFile(url: URL, content: String) async throws {
        guard let rootURL = rootItem?.url else {
            throw FileOperationError.rootDirectoryNotSet
        }
        
        let relativeURL = url.relativePath(from: rootURL)
        let saveURL = rootURL.appendingPathComponent(relativeURL)
        
        guard saveURL.path.hasPrefix(rootURL.path) else {
            throw FileOperationError.fileOutsideRootDirectory
        }
        
        let directory = saveURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            try content.write(to: saveURL, atomically: true, encoding: .utf8)
            print("File saved successfully: \(saveURL.path)")        
        } catch {
            print("Error saving file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteFile(at url: URL) async throws {
        guard let rootURL = rootItem?.url else {
            throw FileOperationError.rootDirectoryNotSet
        }
        
        let relativeURL = url.relativePath(from: rootURL)
        let deleteURL = rootURL.appendingPathComponent(relativeURL)
        
        guard deleteURL.path.hasPrefix(rootURL.path) else {
            throw FileOperationError.fileOutsideRootDirectory
        }
        
        do {
            try FileManager.default.removeItem(at: deleteURL)
            print("File deleted successfully: \(deleteURL.path)")     
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getFileContent(for filePath: String) -> String? {
        return files.first(where: { $0.url.path == filePath })?.content
    }
    
    func updateSelectedFileTypes(_ types: [String]) {
        selectedFileTypes = types
        contextManager?.updateMonitoredFileTypes(types)
    }
    
    private func loadAvailableFileTypes(_ url: URL) async {
        let fileTypes = await Task.detached(priority: .background) { () -> Set<String> in
            let fileManager = FileManager.default
            var fileTypes = Set<String>()
            
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                return fileTypes
            }
            
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                   resourceValues.isRegularFile == true {
                    let fileExtension = fileURL.pathExtension.lowercased()
                    if !fileExtension.isEmpty {
                        fileTypes.insert(fileExtension)
                    }
                }
            }
            
            return fileTypes
        }.value
        
        await MainActor.run {
            self.availableFileTypes = Array(fileTypes).sorted()
            print("Available file types: \(self.availableFileTypes)")
        }
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(context, forType: .string)
    }
    
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to save improved code files"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            setURL(url)
        }
    }
    
    deinit {
        if let rootURL = rootItem?.url {
            directoryManager.stopAccessingSecurityScopedResource(for: rootURL)
        }
    }
    
    enum FileOperationError: Error {
        case rootDirectoryNotSet
        case fileOutsideRootDirectory
    }
}

extension URL {
    func relativePath(from base: URL) -> String {
        let fromPath = self.standardized.path
        let toPath = base.standardized.path
        
        let fromComponents = fromPath.components(separatedBy: "/")
        let toComponents = toPath.components(separatedBy: "/")
        
        var relativeComponents: [String] = []
        var index = 0
        
        while index < fromComponents.count && index < toComponents.count && fromComponents[index] == toComponents[index] {
            index += 1
        }
        
        let toRemaining = toComponents.count - index
        if toRemaining > 0 {
            relativeComponents = Array(repeating: "..", count: toRemaining)
        }
        
        relativeComponents.append(contentsOf: fromComponents[index...])
        
        return relativeComponents.joined(separator: "/")
    }
}
