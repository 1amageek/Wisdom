//
//  BuildManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation

@Observable
class BuildManager {
    var buildCommand: String = "swift build"
    private var buildProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    var buildWorkingDirectory: URL?
    
    var isBuilding = false
    var buildOutputLines: [BuildLog] = []
    var lastBuildStatus: BuildStatus = .none
    var buildError: Error?
    
    func setBuildWorkingDirectory(_ url: URL?) {
        self.buildWorkingDirectory = url
        print("Build working directory set to: \(url?.path ?? "nil")")
    }
    
    func start() async {
        guard !isBuilding else { return }
        guard let workingDirectory = buildWorkingDirectory else {
            lastBuildStatus = .failed(code: -1)
            buildError = BuildError.noWorkingDirectory
            return
        }
        
        isBuilding = true
        buildOutputLines.removeAll()
        lastBuildStatus = .inProgress
        buildError = nil
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        process.environment = environment
        
        process.arguments = ["xcrun", "swift"] + buildCommand.components(separatedBy: " ").dropFirst()
        process.currentDirectoryURL = workingDirectory
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        self.buildProcess = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        
        buildOutputLines.append(.init("Working directory: \(workingDirectory.path)"))
        
        do {
            try process.run()
            
            Task {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    await MainActor.run {
                        self.buildOutputLines.append(.init(line))
                    }
                }
            }
            
            process.waitUntilExit()
            
            isBuilding = false
            
            if process.terminationStatus != 0 {
                lastBuildStatus = .failed(code: process.terminationStatus)
                buildError = BuildError.buildFailed(code: process.terminationStatus)
            } else {
                lastBuildStatus = .success
            }
        } catch {
            isBuilding = false
            lastBuildStatus = .failed(code: -1)
            buildError = error
        }
    }
    
    func stop() {
        buildProcess?.terminate()
        isBuilding = false
        lastBuildStatus = .stopped
    }
    
    private func convertUrlToPath(_ text: String) -> String {
        guard let workingDirectory = buildWorkingDirectory else { return text }
        return text.replacingOccurrences(of: workingDirectory.path, with: ".")
    }
    
    func errors(_ rootURL: URL) -> String {
        return buildOutputLines.map { convertUrlToPath($0.text) }.joined(separator: "\n")
    }
    
    enum BuildError: Error {
        case buildInProgress
        case buildFailed(code: Int32)
        case noWorkingDirectory
    }
    
    enum BuildStatus: Equatable {
        case none
        case inProgress
        case success
        case failed(code: Int32)
        case stopped
    }
}
