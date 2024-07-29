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
    var buildCommand: String = "swift build"
    private var buildProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    var buildWorkingDirectory: URL?
    var buildType: BuildType = .swift
    var errorCount: Int = 0
    var warningCount: Int = 0
    var isBuilding = false
    var buildOutputLines: [BuildLog] = []
    var lastBuildStatus: BuildStatus = .none
    var buildError: Error?
    
    func setBuildWorkingDirectory(_ url: URL?) {
        self.buildWorkingDirectory = url
        print("Build working directory set to: \(url?.path ?? "nil")")
    }
    
    func setBuildType(_ type: BuildType) {
        buildType = type
        resetBuildState()
    }
    
    private func resetBuildState() {
        errorCount = 0
        warningCount = 0
        buildOutputLines.removeAll()
        lastBuildStatus = .none
        buildError = nil
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
