//
//  BuildManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation

actor BuildManager {
    private let fileManager = FileManager.default
    private let buildQueue = DispatchQueue(label: "com.wisdom.buildQueue", qos: .userInitiated)
    
    enum BuildError: Error, LocalizedError {
        case directoryNotFound
        case buildFailed(String)
        case invalidScheme
        
        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "Project directory not found."
            case .buildFailed(let reason):
                return "Build failed: \(reason)"
            case .invalidScheme:
                return "Invalid or unsupported scheme."
            }
        }
    }
    
    struct BuildConfiguration {
        var scheme: String
        var configuration: String
        var extraArguments: [String]
        
        init(scheme: String, configuration: String = "Debug", extraArguments: [String] = []) {
            self.scheme = scheme
            self.configuration = configuration
            self.extraArguments = extraArguments
        }
    }
    
    func build(projectPath: URL, configuration: BuildConfiguration, progress: @escaping (String) -> Void) async throws {
        guard fileManager.fileExists(atPath: projectPath.path) else {
            throw BuildError.directoryNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-project", projectPath.path,
            "-scheme", configuration.scheme,
            "-configuration", configuration.configuration,
            "build"
        ] + configuration.extraArguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let line = String(data: fileHandle.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                progress(line)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let line = String(data: fileHandle.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                progress("Error: \(line)")
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            if process.terminationStatus != 0 {
                print("-------", process.terminationStatus)
                throw BuildError.buildFailed("Process exited with status \(process.terminationStatus)")
            }
        } catch {
            throw BuildError.buildFailed(error.localizedDescription)
        }
    }
    
    func clean(projectPath: URL, scheme: String, progress: @escaping (String) -> Void) async throws {
        guard fileManager.fileExists(atPath: projectPath.path) else {
            throw BuildError.directoryNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-project", projectPath.path, "-scheme", scheme, "clean"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let line = String(data: fileHandle.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                progress(line)
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            outputPipe.fileHandleForReading.readabilityHandler = nil
            
            if process.terminationStatus != 0 {
                throw BuildError.buildFailed("Clean failed with status \(process.terminationStatus)")
            }
        } catch {
            throw BuildError.buildFailed(error.localizedDescription)
        }
    }
    
    func listSchemes(projectPath: URL) async throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-project", projectPath.path, "-list"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard let output = try outputPipe.fileHandleForReading.readToEnd(),
              let outputString = String(data: output, encoding: .utf8) else {
            throw BuildError.buildFailed("Failed to read schemes")
        }
        
        let schemes = outputString.components(separatedBy: "Schemes:")
            .last?
            .components(separatedBy: .newlines)
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        
        return schemes
    }
}
