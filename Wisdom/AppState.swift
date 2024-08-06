//
//  AppState.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

enum SidebarNavigation {
    case fileSystem
    case requirements
}

@Observable
class AppState {
    
    var rootItem: FileItem?
    var selection: Set<FileItem> = []
    var selectedFile: CodeFile?
    var availableFileTypes: [String] = []
    var selectedFileTypes: [String] = ["swift", "tsx", "ts", "js", "py", "rs"]
    var selectedNavigation: SidebarNavigation = .fileSystem
   
    var showingDeleteConfirmation = false
    var isShowingFullContext: Bool = false
    
    // MARK: - Initialization
    init() { }
    
    // MARK: - Directory Management
    func setURL(_ url: URL) {
        do {
            let resolvedURL = try DirectoryManager.shared.setDirectory(url)
            self.rootItem = FileItem(url: resolvedURL)
            self.rootItem?.loadChildren()
            ContextManager.shared.setRootURL(resolvedURL)
            ContextManager.shared.setConfig(ContextManager.Configuration(
                maxDepth: 5,
                excludedDirectories: ["Pods", ".git", ".storybook", "node_modules", ".next", "dataset", "ServiceAccount"],
                maxFileSize: 1_000_000,
                debounceInterval: 0.5,
                monitoredFileTypes: selectedFileTypes
            ))
            
            BuildManager.shared.setRootURL(resolvedURL)
            BuildManager.shared.setBuildWorkingDirectory(resolvedURL)
            RequirementsManager.shared.setRootURL(resolvedURL)
                        
            UserDefaults.standard.set(resolvedURL.path, forKey: "LastOpenedDirectory")
            
            Task {
                await loadAvailableFileTypes(resolvedURL)
                await BuildManager.shared.updateBuildSettingsFromProject()
            }
            
            print("Directory set successfully: \(resolvedURL.path)")
        } catch {
            print("Error setting URL: \(error.localizedDescription)")
        }
    }
    
    func saveFile(_ file: CodeFile) async throws {
        guard let rootURL = rootItem?.url else {
            throw FileOperationError.rootDirectoryNotSet
        }
        guard file.url.path.hasPrefix(rootURL.path) else {
            throw FileOperationError.fileOutsideRootDirectory
        }
        let relativePath = file.url.relativePath(from: rootURL)
        try await saveFile(path: relativePath, content: file.content)
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
    
    func handleDeleteKeyPress() {
        let selectedFiles = self.selection.filter { !$0.isDirectory }
        if !selectedFiles.isEmpty {
            showingDeleteConfirmation = true
        }
    }
    
    func moveSelectedFilesToTrash() {
        let selectedItems = selection.filter { !$0.isDirectory }
        guard !selectedItems.isEmpty else { return }
        
        do {
            let fileManager = FileManager.default
            for item in selectedItems {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
            }
            
            selection.removeAll()
            selectedFile = nil
            // ファイルシステムビューを更新
//            rootItem?.loadChildren()
        } catch {
            print("Error moving files to trash: \(error)")
        }
    }
    
    func updateSelectedFileTypes(_ types: [String]) {
        selectedFileTypes = types
        ContextManager.shared.updateMonitoredFileTypes(types)
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
    
    func startAgent(with message: String, agent: Agent) async {
        
        let buildClosure: Agent.BuildClosure = {
            await BuildManager.shared.start()
            let errorCount = BuildManager.shared.buildOutputLines.count
            let successful = BuildManager.shared.lastBuildStatus == .success
            return (errorCount, successful)
        }
        
        let generateClosure: Agent.GenerateClosure = { message, buildErrors in
            let proposal = try await Functions.shared.improve(
                userID: "testUser",
                packageID: "testPackage",
                message: message,
                requirementsAndSpecification: RequirementsManager.shared.context(),
                sources: ContextManager.shared.getFullContext(),
                errors: BuildManager.shared.errors()
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
 
        await agent.start(with: message, build: buildClosure, generate: generateClosure, fileOperation: fileOperationClosure)
    }
    
    func stopAgent() async {
        Agent.shared.stop()
    }
}

extension AppState {
    
    func createNewFileFromClipboard() async {
        guard let targetURL = getTargetDirectoryURL() else {
            print("No valid target directory selected")
            return
        }

        let (typeName, fileExtension) = getTypeNameAndExtensionFromClipboard()
        let fileName = typeName ?? "NewFile"
        let ext = fileExtension ?? "txt"

        let pasteboard = NSPasteboard.general
        guard let content = pasteboard.string(forType: .string) else {
            print("No text content in clipboard")
            return
        }

        let newFileURL = targetURL.appendingPathComponent("\(fileName).\(ext)")
        let file = CodeFile(url: newFileURL, content: content)

        do {
            try await saveFile(file)
            print("File saved successfully: \(newFileURL.path)")
            // ファイルシステムビューを更新
            rootItem?.loadChildren()
        } catch {
            print("Error saving file: \(error)")
        }
    }

    private func getTargetDirectoryURL() -> URL? {
        if let selectedItem = selection.first {
            if selectedItem.isDirectory {
                return selectedItem.url
            } else {
                return selectedItem.url.deletingLastPathComponent()
            }
        } else if let rootURL = rootItem?.url {
            return rootURL
        }
        return nil
    }
    
    func getTypeNameFromClipboard() -> String? {
         let pasteboard = NSPasteboard.general
         guard let clipboardString = pasteboard.string(forType: .string) else {
             return nil
         }
         let pattern = "(class|struct|enum|actor)\\s+(\\w+)"
         let regex = try? NSRegularExpression(pattern: pattern, options: [])
         if let match = regex?.firstMatch(in: clipboardString, options: [], range: NSRange(location: 0, length: clipboardString.utf16.count)) {
             if let typeNameRange = Range(match.range(at: 2), in: clipboardString) {
                 return String(clipboardString[typeNameRange])
             }
         }
         return nil
     }
    
    func getFileExtensionFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string) {
            if clipboardString.contains("func ") || clipboardString.contains("class ") || clipboardString.contains("struct ") {
                return "swift"
            }
        }
        guard let types = pasteboard.types,
              let uti = types.first(where: { UTType($0.rawValue)?.conforms(to: .content) == true }) else {
            return nil
        }
        if let utType = UTType(uti.rawValue),
           let preferredExtension = utType.preferredFilenameExtension {
            return preferredExtension
        }
        return nil
    }

    func getTypeNameAndExtensionFromClipboard() -> (typeName: String?, fileExtension: String?) {
        let typeName = getTypeNameFromClipboard()
        let fileExtension = getFileExtensionFromClipboard()
        return (typeName, fileExtension)
    }
}
