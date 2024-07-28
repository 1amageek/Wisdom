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
    var buildErrorLines: [BuildLog] = []
    var lastBuildStatus: BuildStatus = .none
    
    func setBuildWorkingDirectory(_ url: URL?) {
        self.buildWorkingDirectory = url
        print("Build working directory set to: \(url?.path ?? "nil")")
    }
    
    func start() async throws {
        guard !isBuilding else { throw BuildError.buildInProgress }
        guard let workingDirectory = buildWorkingDirectory else { throw BuildError.noWorkingDirectory }
        
        isBuilding = true
        buildOutputLines.removeAll()
        buildErrorLines.removeAll()
        lastBuildStatus = .inProgress
        
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
            
            Task {
                for try await line in errorPipe.fileHandleForReading.bytes.lines {
                    await MainActor.run {
                        self.buildErrorLines.append(.init(line))
                    }
                }
            }
            
            process.waitUntilExit()
            
            isBuilding = false
            
            if process.terminationStatus != 0 {
                lastBuildStatus = .failed(code: process.terminationStatus)
                throw BuildError.buildFailed(code: process.terminationStatus)
            } else {
                lastBuildStatus = .success
            }
        } catch {
            isBuilding = false
            lastBuildStatus = .failed(code: -1)
            throw error
        }
    }
    
    func stop() {
        buildProcess?.terminate()
        isBuilding = false
        lastBuildStatus = .stopped
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
