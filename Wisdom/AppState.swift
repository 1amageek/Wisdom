//
//  AppState.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
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
    
    var buildManager: BuildManager = BuildManager()
    
    var context: String { self.contextManager?.getFullContext() ?? "" }
    
    var availableSchemes: [String] = []
    
    var selectedScheme: String = "Wisdom"
    
    var buildConfiguration: String = "Debug"
    
    var buildProgress: String = ""
    
    init() {
        self.loadSavedDirectory()        
    }
    
    func setURL(_ url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "RootDirectoryBookmark")
            UserDefaults.standard.set(url.path, forKey: "LastOpenedDirectory")
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }
            
            self.rootItem = FileItem(url: url)
            self.contextManager = ContextManager(rootURL: url, config: ContextManager.Configuration(
                maxDepth: 5,
                excludedDirectories: ["Pods", ".git"],
                maxFileSize: 1_000_000,
                debounceInterval: 0.5,
                monitoredFileTypes: selectedFileTypes
            ))
            
            Task {
                await loadAvailableFileTypes(url)
            }
            
            print("Directory set and bookmarked successfully: \(url.path)")
        } catch {
            print("Error setting URL and creating bookmark: \(error.localizedDescription)")
        }
    }
    
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            setURL(url)
        }
    }
    
    private func loadSavedDirectory() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "RootDirectoryBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    setURL(url)
                } else {
                    guard url.startAccessingSecurityScopedResource() else {
                        print("Failed to access security scoped resource")
                        return
                    }
                    
                    self.rootItem = FileItem(url: url)
                    self.contextManager = ContextManager(rootURL: url, config: ContextManager.Configuration(
                        maxDepth: 5,
                        excludedDirectories: ["Pods", ".git"],
                        maxFileSize: 1_000_000,
                        debounceInterval: 0.5,
                        monitoredFileTypes: selectedFileTypes
                    ))
                    print("Loaded bookmarked directory: \(url.path)")
                    
                    Task {
                        await loadAvailableFileTypes(url)
                    }
                }
            } catch {
                print("Error resolving bookmark: \(error.localizedDescription)")
                loadFallbackDirectory()
            }
        } else {
            loadFallbackDirectory()
        }
    }
    
    private func loadFallbackDirectory() {
        if let lastPath = UserDefaults.standard.string(forKey: "LastOpenedDirectory"),
           let url = URL(string: lastPath) {
            setURL(url)
        } else {
            print("No saved directory found")
        }
    }
    
    private func loadAvailableFileTypes(_ url: URL) async {
        let fileTypes = await Task.detached(priority: .background) { () -> Set<String> in
            let fileManager = FileManager.default
            var fileTypes = Set<String>()
            
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                return fileTypes
            }
            
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if resourceValues.isRegularFile == true {
                        let fileExtension = fileURL.pathExtension.lowercased()
                        if !fileExtension.isEmpty {
                            fileTypes.insert(fileExtension)
                        }
                    }
                } catch {
                    print("Error accessing file \(fileURL.path): \(error.localizedDescription)")
                }
            }
            
            return fileTypes
        }.value
        
        await MainActor.run {
            self.availableFileTypes = Array(fileTypes).sorted()
            print("Available file types: \(self.availableFileTypes)")
        }
    }
    
    func updateSelectedFileTypes(_ types: [String]) {
        selectedFileTypes = types
        contextManager?.updateMonitoredFileTypes(types)
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(context, forType: .string)
    }
    
    deinit {
        rootItem?.url.stopAccessingSecurityScopedResource()
    }
}

// MARK: - ServerManager

extension AppState {
    
    var files: [CodeFile] { self.contextManager?.files ?? [] }
    
    func isServerRunning() async -> Bool {
        return await self.serverManager.isServerRunning()
    }
    
    func startServer() async {
        do {
            try await serverManager.start()
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stopServer() async {
        do {
            try await serverManager.stop()
        } catch {
            print("Failed to stop server: \(error)")
        }
    }
}

// MARK: - BuildManager

extension AppState {
    
    func buildProject() async throws {
        guard let projectURL = rootItem?.url else {
            throw BuildManager.BuildError.directoryNotFound
        }
        
        let configuration = BuildManager.BuildConfiguration(
            scheme: selectedScheme,
            configuration: buildConfiguration
        )
        
        try await buildManager.build(projectPath: projectURL, configuration: configuration) { progress in
            Task { @MainActor in
                self.buildProgress = progress
            }
        }
    }
    
    func cleanProject() async throws {
        guard let projectURL = rootItem?.url else {
            throw BuildManager.BuildError.directoryNotFound
        }
        try await buildManager.clean(projectPath: projectURL, scheme: selectedScheme) { progress in
            Task { @MainActor in
                self.buildProgress = progress
            }
        }
    }
    
    func loadAvailableSchemes() async {
         guard let projectURL = rootItem?.url else { return }
         do {
             self.availableSchemes = try await buildManager.listSchemes(projectPath: projectURL)
             if !availableSchemes.isEmpty && !availableSchemes.contains(selectedScheme) {
                 selectedScheme = availableSchemes[0]
             }
         } catch {
             print("Failed to load schemes: \(error.localizedDescription)")
         }
     }
}
