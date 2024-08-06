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
    }
    
    enum ProjectType: String {
        case spm
        case xcodeproj
        case xcworkspace
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
            case .unknown:
                buildTool = .spm // Default to SPM
            }
        }
        resetBuildState()
        updateBuildCommand()
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
    
    // MARK: - Private Methods
    private func resetBuildState() {
        errorCount = 0
        warningCount = 0
        buildOutputLines.removeAll()
        lastBuildStatus = .none
        buildError = nil
    }
    
    private func updateBuildCommand() {
        switch buildTool {
        case .spm:
            customBuildCommand = "swift build"
        case .xcodebuild:
            if let url = currentProjectURL {
                let projectName = url.lastPathComponent
                customBuildCommand = "xcodebuild -project \"\(projectName)\""
            }
        }
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
    
    // MARK: - Computed Properties
    var buildCommand: String {
        if let custom = customBuildCommand {
            return custom
        }
        
        var command = buildTool == .spm ? "swift build" : "xcodebuild"
        
        if buildTool == .xcodebuild {
            if let schema = schemaManager.selectedSchema {
                command += " -scheme \(schema)"
            }
            // Add more xcodebuild specific options here
        } else {
            if let configuration = schemaManager.selectedSchema {
                command += " -c \(configuration)"
            }
            // Add more SPM specific options here
        }
        
        return command
    }
}
