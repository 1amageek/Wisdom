//
//  AppState.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import Foundation
import AppKit

enum SidebarNavigation {
    case fileSystem
    case requirements
}

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
    var isAgentRunning = false
    var selectedNavigation: SidebarNavigation = .fileSystem
    
    private var agent: Agent?
    private var directoryManager = DirectoryManager()
    
    // MARK: - Initialization
    init() {
        if let url = directoryManager.loadSavedDirectory() {
            setURL(url)
        }
    }
    
    // MARK: - Directory Management
    func setURL(_ url: URL) {
        do {
            let resolvedURL = try directoryManager.setDirectory(url)
            self.rootItem = FileItem(url: resolvedURL)
            self.rootItem?.loadChildren()
            self.contextManager = ContextManager(rootURL: resolvedURL, config: ContextManager.Configuration(
                maxDepth: 5,
                excludedDirectories: ["Pods", ".git"],
                maxFileSize: 1_000_000,
                debounceInterval: 0.5,
                monitoredFileTypes: selectedFileTypes
            ))
            
            RequirementsManager.shared.setRootURL(resolvedURL)
            
            UserDefaults.standard.set(resolvedURL.path, forKey: "LastOpenedDirectory")
            
            Task {
                await loadAvailableFileTypes(resolvedURL)
            }
            
            print("Directory set successfully: \(resolvedURL.path)")
        } catch {
            print("Error setting URL: \(error.localizedDescription)")
        }
    }
    
    func saveFile(path: String, content: String) async throws {
        guard let rootURL = rootItem?.url else {
            throw FileOperationError.rootDirectoryNotSet
        }
        let saveURL = rootURL.appendingPathComponent(path)
        // セキュリティチェック：保存先がrootURL以下であることを確認
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
            
            // ContextManagerの更新（必要に応じて）
            if let contextManager = self.contextManager {
                await contextManager.addOrUpdateFile(at: saveURL)
            }
        } catch {
            print("Error saving file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteFile(path: String) async throws {
        guard let rootURL = rootItem?.url else {
            throw FileOperationError.rootDirectoryNotSet
        }
        let deleteURL = rootURL.appendingPathComponent(path)
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

extension AppState {
    
    func startAgent(with message: String, agent: Agent, buildManager: BuildManager) async {
        
        let buildClosure: Agent.BuildClosure = {
            await buildManager.start()
            let errorCount = buildManager.buildOutputLines.count
            let successful = buildManager.lastBuildStatus == .success
            return (errorCount, successful)
        }
        
        let generateClosure: Agent.GenerateClosure = { message, buildErrors in
            let proposal = try await Functions.shared.improve(
                userID: "testUser",
                packageID: "testPackage",
                message: message
            )
            
            
            return proposal
        }
        
        let fileOperationClosure: Agent.FileOperationClosure = { operation in
            switch operation.actionType {
            case .create, .update:
                guard let content = operation.content else {
                    throw NSError(domain: "FileOperation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Content is required for create and update operations"])
                }
                try await self.saveFile(path: operation.path, content: content)
            case .delete:
                try await self.deleteFile(path: operation.path)
            }
        }
        
        isAgentRunning = true
        await agent.start(with: message, build: buildClosure, generate: generateClosure, fileOperation: fileOperationClosure)
        isAgentRunning = false
    }
    
    func stopAgent() async {
        agent?.stop()
        isAgentRunning = false
    }
}
