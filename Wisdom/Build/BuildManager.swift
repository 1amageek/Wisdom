//
//  BuildManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation
import SwiftUI

@Observable
class BuildManager {
    enum BuildTool {
        case spm
        case xcodebuild
        case npm
    }
    
    enum ProjectType: String {
        case spm
        case xcodeproj
        case xcworkspace
        case nodejs
        case unknown
    }
    
    enum BuildStatus: Equatable {
        case none
        case inProgress
        case success
        case failed(code: Int32)
        case stopped
    }
    
    enum BuildError: Error {
        case buildInProgress
        case buildFailed(code: Int32)
        case noWorkingDirectory
        case invalidPackageInfo
    }
    
    // MARK: - Properties
    var buildTool: BuildTool = .spm
    var rootURL: URL?
    var buildWorkingDirectory: URL?
    var currentProjectURL: URL?
    var detectedProjects: [URL: ProjectType] = [:]
    
    private var buildProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var customBuildCommand: String?
    
    let schemaManager: SchemaManager
    
    var errorCount: Int = 0
    var warningCount: Int = 0
    var isBuilding = false
    var buildOutputLines: [BuildLog] = []
    var lastBuildStatus: BuildStatus = .none
    var buildError: Error?
    
    var availablePlatforms: [String] = []
    var selectedPlatform: String?
    var availableScripts: [String] = []
    var selectedScript: String?
    
    static let shared = BuildManager()
    
    // MARK: - Initialization
    init() {
        self.schemaManager = SchemaManager()
    }
    
    // MARK: - Public Methods
    func setRootURL(_ url: URL) {
        self.rootURL = url
        detectProjects(in: url)
    }
    
    func setBuildWorkingDirectory(_ url: URL?) {
        self.buildWorkingDirectory = url
        print("Build working directory set to: \(url?.path ?? "nil")")
    }
    
    func detectProjects(in rootURL: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "xcodeproj" {
                detectedProjects[fileURL] = .xcodeproj
            } else if fileURL.pathExtension == "xcworkspace" {
                detectedProjects[fileURL] = .xcworkspace
            } else if fileURL.lastPathComponent == "Package.swift" {
                detectedProjects[fileURL.deletingLastPathComponent()] = .spm
            } else if fileURL.lastPathComponent == "package.json" {
                detectedProjects[fileURL.deletingLastPathComponent()] = .nodejs
            }
        }
    }

    func setCurrentProject(_ url: URL) {
        currentProjectURL = url
        if let projectType = detectedProjects[url] {
            switch projectType {
            case .spm:
                buildTool = .spm
            case .xcodeproj, .xcworkspace:
                buildTool = .xcodebuild
            case .nodejs:
                buildTool = .npm
            case .unknown:
                buildTool = .spm
            }
        }
        resetBuildState()
        Task {
            await updateBuildSettingsFromProject()
        }
    }
    
    func setCustomBuildCommand(_ command: String?) {
        self.customBuildCommand = command
        if let command = command {
            print("Custom build command set: \(command)")
        } else {
            print("Custom build command cleared")
        }
    }

    func clearCustomBuildCommand() {
        self.customBuildCommand = nil
        print("Custom build command cleared")
    }

    func isUsingCustomCommand() -> Bool {
        return customBuildCommand != nil
    }
    
    func start() async {
        guard !isBuilding else { return }
        guard let workingDirectory = buildWorkingDirectory else {
            lastBuildStatus = .failed(code: -1)
            buildError = BuildError.noWorkingDirectory
            return
        }
        
        withAnimation {
            isBuilding = true
        }
        resetBuildState()
        lastBuildStatus = .inProgress
        buildError = nil
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        process.environment = environment
        
        process.arguments = buildCommand.components(separatedBy: " ")
        process.currentDirectoryURL = workingDirectory
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        self.buildProcess = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        
        buildOutputLines.append(.init("Working directory: \(workingDirectory.path)"))
        buildOutputLines.append(.init("Build command: \(buildCommand)"))
        
        do {
            try process.run()
            
            Task {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    await MainActor.run {
                        self.buildOutputLines.append(.init(line))
                        if line.contains("error:") {
                            self.errorCount += 1
                        } else if line.contains("warning:") {
                            self.warningCount += 1
                        }
                    }
                }
            }
            
            process.waitUntilExit()

            withAnimation {
                isBuilding = false
            }
            
            if process.terminationStatus != 0 {
                lastBuildStatus = .failed(code: process.terminationStatus)
                buildError = BuildError.buildFailed(code: process.terminationStatus)
            } else {
                lastBuildStatus = .success
            }
        } catch {
            withAnimation {
                isBuilding = false
            }
            lastBuildStatus = .failed(code: -1)
            buildError = error
        }
    }
    
    func stop() {
        buildProcess?.terminate()
        isBuilding = false
        lastBuildStatus = .stopped
    }
    
    func errors() -> String {
        return buildOutputLines.map { convertUrlToPath($0.text) }.joined(separator: "\n")
    }
    
    func updateBuildSettingsFromProject() async {
        guard let projectType = detectedProjects[currentProjectURL ?? URL(fileURLWithPath: "")] else {
            print("No project detected")
            return
        }

        switch projectType {
        case .spm:
            await updateSwiftPackageSettings()
        case .xcodeproj, .xcworkspace:
            await updateXcodeProjectSettings()
        case .nodejs:
            await updateNodeJSSettings()
        case .unknown:
            print("Unknown project type")
        }
        
        updateBuildCommand()
    }

    // MARK: - Private Methods
    private func resetBuildState() {
        errorCount = 0
        warningCount = 0
        buildOutputLines.removeAll()
        lastBuildStatus = .none
        buildError = nil
    }
    
    func updateBuildCommand() {
        var command = ""
        switch buildTool {
        case .spm:
            command = "swift build"
            if let platform = selectedPlatform {
                command += " --platform \(platform)"
            }
        case .xcodebuild:
            command = "xcodebuild"
            if let schema = schemaManager.selectedSchema {
                command += " -scheme \(schema)"
            }
        case .npm:
            if let script = selectedScript {
                command = "npm run \(script)"
            } else {
                command = "npm run build"
            }
        }

        if let customCommand = customBuildCommand {
            command = customCommand
        }

        setCustomBuildCommand(command)
    }
    
    private func parseOutput(_ line: String) {
        if line.lowercased().contains("error") {
            errorCount += 1
        } else if line.lowercased().contains("warning") {
            warningCount += 1
        }
        buildOutputLines.append(.init(line))
    }
    
    private func convertUrlToPath(_ text: String) -> String {
        guard let workingDirectory = buildWorkingDirectory else { return text }
        return text.replacingOccurrences(of: workingDirectory.path, with: ".")
    }
    
    private func updateSwiftPackageSettings() async {
        do {
            let packageInfo = try await fetchPackageInfo()
            if let platforms = packageInfo["platforms"] as? [[String: Any]] {
                availablePlatforms = platforms.compactMap { $0["platformName"] as? String }
                if let first = availablePlatforms.first {
                    selectedPlatform = first
                }
            }
            if let targets = packageInfo["targets"] as? [[String: Any]] {
                schemaManager.availableSchemas = targets.compactMap { $0["name"] as? String }
                if let firstTarget = schemaManager.availableSchemas.first {
                    schemaManager.selectedSchema = firstTarget
                }
            }
        } catch {
            print("Error fetching Swift package info: \(error)")
        }
    }

    private func updateXcodeProjectSettings() async {
        // Implementation for Xcode project settings
        // This might involve parsing the project file or using xcodebuild -list
        // For now, we'll just set a placeholder
        schemaManager.availableSchemas = ["Debug", "Release"]
        schemaManager.selectedSchema = "Debug"
    }

    private func updateNodeJSSettings() async {
        do {
            let packageInfo = try await fetchPackageJSON()
            if let scripts = packageInfo["scripts"] as? [String: String] {
                availableScripts = Array(scripts.keys)
                if let first = availableScripts.first {
                    selectedScript = first
                }
            }
        } catch {
            print("Error fetching package.json info: \(error)")
        }
    }

    func fetchPackageInfo() async throws -> [String: Any] {
        guard let workingDirectory = buildWorkingDirectory else {
            throw BuildError.noWorkingDirectory
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "package", "dump-package"]
        process.currentDirectoryURL = workingDirectory

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard let packageInfo = jsonObject as? [String: Any] else {
            throw BuildError.invalidPackageInfo
        }

        return packageInfo
    }

    func fetchPackageJSON() async throws -> [String: Any] {
        guard let workingDirectory = buildWorkingDirectory else {
            throw BuildError.noWorkingDirectory
        }

        let packageJSONURL = workingDirectory.appendingPathComponent("package.json")
        let data = try Data(contentsOf: packageJSONURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard let packageInfo = jsonObject as? [String: Any] else {
            throw BuildError.invalidPackageInfo
        }

        return packageInfo
    }
    
    // MARK: - Computed Properties
    var buildCommand: String {
        customBuildCommand ?? {
            switch buildTool {
            case .spm:
                var command = "swift build"
                if let platform = selectedPlatform {
                    command += " --platform \(platform)"
                }
                return command
            case .xcodebuild:
                var command = "xcodebuild"
                if let schema = schemaManager.selectedSchema {
                    command += " -scheme \(schema)"
                }
                return command
            case .npm:
                if let script = selectedScript {
                    return "npm run \(script)"
                } else {
                    return "npm run build"
                }
            }
        }()
    }
}
