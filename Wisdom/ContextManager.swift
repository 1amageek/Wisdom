//
//  ContextManager.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/24.
//

import Foundation
import SwiftUI
import os.log
import UniformTypeIdentifiers

@Observable
class ContextManager {
    private(set) var files: [CodeFile] = []
    private(set) var isLoading: Bool = false
    private var fileObserver: FileSystemObserver?
    private let rootURL: URL
    private let logger = Logger(subsystem: "team.stamp.ContextManager", category: "FileManagement")
    
    private var fullContext: String = ""
    private var fileContexts: [String: String] = [:]
    private var isContextDirty: Bool = false
    
    struct Configuration {
        let maxDepth: Int
        let excludedDirectories: [String]
        let maxFileSize: Int
        let debounceInterval: TimeInterval
        var monitoredFileTypes: [String]
    }
    
    private var config: Configuration
    
    private var updateWorkItem: DispatchWorkItem?
    
    init(rootURL: URL, config: Configuration = Configuration(maxDepth: 5, excludedDirectories: ["Pods", ".git"], maxFileSize: 1_000_000, debounceInterval: 0.5, monitoredFileTypes: ["swift"])) {
        self.rootURL = rootURL
        self.config = config
        setupFileObserver()
    }
    
    func updateMonitoredFileTypes(_ fileTypes: [String]) {
        config.monitoredFileTypes = fileTypes
        fileObserver?.stopObserving()
        setupFileObserver()
        isContextDirty = true
        Task {
            await loadInitialFiles()
        }
    }
    
    private func setupFileObserver() {
        let configuration = FileSystemObserver.Configuration(
            url: rootURL,
            filterType: .extensions(config.monitoredFileTypes),
            includeSubdirectories: true,
            latency: 0.1,
            queue: DispatchQueue(label: "com.contextmanager.fileobserver", qos: .utility)
        )
        
        fileObserver = FileSystemObserver(configuration: configuration) { [weak self] event in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch event {
                case .created(let url), .modified(let url):
                    await self.addOrUpdateFile(at: url)
                case .deleted(let url):
                    self.removeFile(at: url)
                case .renamed(let oldURL, let newURL):
                    self.renameFile(from: oldURL, to: newURL)
                }
                
                self.debounceContextUpdate()
            }
        }
        
        fileObserver?.startObserving()
        logger.info("Started watching \(self.rootURL.path)")
        
        Task {
            await loadInitialFiles()
        }
    }
    
    private func debounceContextUpdate() {
        updateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateContextIfNeeded()
        }
        
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.debounceInterval, execute: workItem)
    }
    
    private func loadInitialFiles() async {
        var loadedFiles = 0
        var accessDeniedDirectories: [String] = []

        func loadFiles(in directory: URL, currentDepth: Int) async {
            guard currentDepth <= config.maxDepth else { return }
            
            do {
                let fileURLs = try await Task.detached(priority: .utility) { () -> [URL] in
                    let fileManager = FileManager.default
                    return try fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                        options: [.skipsHiddenFiles]
                    )
                }.value
                
                for fileURL in fileURLs {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                        
                        if let isDirectory = resourceValues.isDirectory, isDirectory {
                            if !config.excludedDirectories.contains(fileURL.lastPathComponent) {
                                await loadFiles(in: fileURL, currentDepth: currentDepth + 1)
                            }
                        } else if config.monitoredFileTypes.contains(fileURL.pathExtension.lowercased()) {
                            if let fileSize = resourceValues.fileSize, fileSize <= config.maxFileSize {
                                await addOrUpdateFile(at: fileURL)
                                loadedFiles += 1
                            } else {
                                logger.warning("File \(fileURL.lastPathComponent) exceeds max size limit")
                            }
                        }
                    } catch {
                        logger.error("Error processing file \(fileURL.path): \(error.localizedDescription)")
                    }
                }
            } catch let error as NSError {
                if error.code == NSFileReadNoPermissionError {
                    accessDeniedDirectories.append(directory.path)
                    logger.error("Permission denied for directory: \(directory.path)")
                } else {
                    logger.error("Error listing contents of directory \(directory.path): \(error.localizedDescription)")
                    logger.error("Error domain: \(error.domain), code: \(error.code)")
                }
            }
        }
        
        await loadFiles(in: rootURL, currentDepth: 0)
        logger.info("Loaded \(loadedFiles) initial files from \(self.rootURL.path) and its subdirectories")
        
        if !accessDeniedDirectories.isEmpty {
            await handleAccessDeniedDirectories(accessDeniedDirectories)
        }
        
        isContextDirty = true
        updateFullContext()
    }
    
    private func handleAccessDeniedDirectories(_ directories: [String]) async {
        let directoryList = directories.joined(separator: "\n")
        logger.warning("Access denied to the following directories:\n\(directoryList)")
        
        // ユーザーに通知を表示
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Permission Required"
            alert.informativeText = "ContextManager needs permission to access the following directories:\n\n\(directoryList)\n\nPlease grant access in System Preferences > Security & Privacy > Privacy > Files and Folders."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
            }
        }
    }
    
    func addOrUpdateFile(at url: URL) async {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.warning("Attempted to add/update non-existent file: \(url.lastPathComponent)")
                removeFile(at: url)
                return
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            guard fileSize <= config.maxFileSize else {
                logger.warning("File \(url.lastPathComponent) exceeds max size limit (\(fileSize) > \(self.config.maxFileSize))")
                return
            }
            
            let content = try String(contentsOf: url, encoding: .utf8)
            if let index = files.firstIndex(where: { $0.url == url }) {
                files[index].content = content
                logger.info("File updated: \(url.lastPathComponent)")
            } else {
                let swiftFile = CodeFile(url: url, content: content)
                files.append(swiftFile)
                logger.info("File added: \(url.lastPathComponent)")
            }
            isContextDirty = true
        } catch {
            logger.error("Error adding/updating file \(url.lastPathComponent): \(error.localizedDescription)")
            removeFile(at: url)
        }
    }
    
    private func removeFile(at url: URL) {
        let initialCount = files.count
        files.removeAll(where: { $0.url == url })
        let removedCount = initialCount - files.count
        if removedCount > 0 {
            logger.info("File removed: \(url.lastPathComponent)")
            isContextDirty = true
        } else {
            logger.warning("Attempted to remove non-existent file: \(url.lastPathComponent)")
        }
    }
    
    private func renameFile(from oldURL: URL, to newURL: URL) {
        if let index = files.firstIndex(where: { $0.url == oldURL }) {
            files[index].url = newURL
            logger.info("File renamed from \(oldURL.lastPathComponent) to \(newURL.lastPathComponent)")
            isContextDirty = true
        } else {
            logger.warning("Attempted to rename non-existent file: \(oldURL.lastPathComponent)")
        }
    }
    
    // New method for getting full context (for server use)
    func getFullContext() -> String {
        if isContextDirty {
            updateFullContext()
        }
        return fullContext
    }
    
    // New method for getting context of a specific file (for server use)
    func getFileContext(for filePath: String) -> String? {
        return fileContexts[filePath]
    }
    
    // New method for getting context based on FileSystemView selection
    func getSelectedContext(for selectedItems: Set<FileItem>) async -> String {
        await MainActor.run { isLoading = true }
        let selectedFiles = files.filter { file in
            selectedItems.contains { item in
                file.url.path.hasPrefix(item.url.path)
            }
        }
        let formattedContext = formatFiles(selectedFiles)
        await MainActor.run { isLoading = false }
        return formattedContext
    }
    
    private func updateFullContext() {
        let directoryTree = generateDirectoryTree(for: rootURL)
        let filesContent = formatFiles(files)
        fullContext = directoryTree + "\n\n" + filesContent
        isContextDirty = false
    }
    
    private func formatFiles(_ filesToFormat: [CodeFile]) -> String {
        let formattedFiles = filesToFormat
            .filter { config.monitoredFileTypes.contains($0.fileType) }
            .lazy
            .map { file in
                let relativePath = file.url.relativePath(from: self.rootURL)
                let content = """
                path: \(relativePath)
                ```\(file.fileType):\(file.url.lastPathComponent)
                \(file.content)
                ```
                """
                self.fileContexts[file.url.path] = content
                return content
            }
        return formattedFiles.joined(separator: "\n\n")
    }
    
    private func updateContextIfNeeded() {
        if isContextDirty {
            updateFullContext()
        }
    }
    
    deinit {
        fileObserver?.stopObserving()
    }
}


extension ContextManager {
    
    private func generateDirectoryTree(for url: URL, depth: Int = 0) -> String {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return ""
        }
        
        var result = ""
        var directoryStructure: [Int: Bool] = [:] // depth: isLastDirectory
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory, isDirectory else {
                continue // Skip non-directory items
            }
            
            let relativeDepth = fileURL.pathComponents.count - url.pathComponents.count
            
            // Update directory structure
            directoryStructure[relativeDepth] = true
            for key in directoryStructure.keys where key > relativeDepth {
                directoryStructure.removeValue(forKey: key)
            }
            
            // Generate tree structure
            for i in 0..<relativeDepth {
                if i == relativeDepth - 1 {
                    result += directoryStructure[i, default: true] ? "└── " : "├── "
                } else {
                    result += directoryStructure[i, default: true] ? "    " : "│   "
                }
            }
            
            result += "\(fileURL.lastPathComponent)\n"
        }
        
        return result
    }
}
