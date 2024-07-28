//
//  Agent.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import Foundation
import os

public enum AgentFileOperationType: String, Codable {
    case create
    case update
    case delete
}

public struct AgentFileOperation: Identifiable, Codable {
    public var id: String
    public var language: String
    public let type: AgentFileOperationType
    public let path: String
    public let content: String?
}

public struct AgentFileProposal: Identifiable, Codable {
    public var id: String
    public var operations: [AgentFileOperation]
    public var timestamp: Date
}

public struct AgentLog: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let type: LogType
    public let message: String
    public var details: String?
    
    public enum LogType: String, Codable {
        case info
        case warning
        case error
        case action
    }
    
    init(type: LogType, message: String, details: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.message = message
        self.details = details
    }
}

@Observable
public class Agent {
    // タイプエイリアス
    public typealias BuildResult = (errorCount: Int, successful: Bool)
    public typealias BuildClosure = () async throws -> BuildResult
    public typealias GeneratorClosure = (String, String) async throws -> AgentFileProposal
    public typealias FileOperationClosure = (AgentFileOperation) async throws -> Void
    
    // プロパティ
    private let buildClosure: BuildClosure
    private let generatorClosure: GeneratorClosure
    private let fileOperationClosure: FileOperationClosure
    private let maxNoImprovementCount: Int
    private let continueOnSuccess: Bool
    private let logger: Logger
    
    public private(set) var logs: [AgentLog] = []
    
    public private(set) var isRunning: Bool = false
    public private(set) var currentErrorCount: Int = 0
    public private(set) var noImprovementCount: Int = 0
    private var lastErrorCount: Int = 0
    
    public init(
        buildClosure: @escaping BuildClosure,
        generatorClosure: @escaping GeneratorClosure,
        fileOperationClosure: @escaping FileOperationClosure,
        maxNoImprovementCount: Int = 3,
        continueOnSuccess: Bool = true
    ) {
        self.buildClosure = buildClosure
        self.generatorClosure = generatorClosure
        self.fileOperationClosure = fileOperationClosure
        self.maxNoImprovementCount = maxNoImprovementCount
        self.continueOnSuccess = continueOnSuccess
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.Wisdom", category: "Agent")
    }
    
    public func start(with message: String) async {
        guard !isRunning else {
            addLog(.warning, "Agent is already running, ignoring start request")
            return
        }
        isRunning = true
        noImprovementCount = 0
        lastErrorCount = Int.max
        
        addLog(.info, "Agent started with message: \(message)")
        
        var firstRun = true
        while isRunning && (firstRun || noImprovementCount < maxNoImprovementCount) {
            let shouldContinue = await runCycle(with: message)
            firstRun = false
            if !shouldContinue {
                addLog(.info, "Cycle completed, breaking loop")
                break
            }
        }
        
        addLog(.info, "Agent stopped")
        isRunning = false
    }
    
    public func stop() {
        if isRunning {
            addLog(.info, "Agent stop requested")
            isRunning = false
        } else {
            addLog(.info, "Agent stop requested, but agent was not running")
        }
    }
    
    private func runCycle(with message: String) async -> Bool {
        do {
            let (currentErrorCount, buildSuccessful) = try await buildClosure()
            self.currentErrorCount = currentErrorCount
            
            if currentErrorCount >= lastErrorCount {
                noImprovementCount += 1
                addLog(.warning, "No improvement in error count", details: "Current: \(currentErrorCount), Last: \(self.lastErrorCount)")
            } else {
                noImprovementCount = 0
                addLog(.info, "Error count improved", details: "From \(self.lastErrorCount) to \(currentErrorCount)")
            }
            lastErrorCount = currentErrorCount
            
            let buildStatus = buildSuccessful ? "successful" : "failed"
            let buildErrors = "Build \(buildStatus) with \(currentErrorCount) errors."
            addLog(.info, buildErrors)
            
            let proposal: AgentFileProposal = try await generatorClosure(message, buildErrors)
            addLog(.info, "Generated proposal", details: "Operations count: \(proposal.operations.count)")
            
            for operation in proposal.operations {
                try await fileOperationClosure(operation)
                addLog(.action, "Executed file operation", details: "\(operation.type.rawValue) on \(operation.path)")
            }
            
            if buildSuccessful && !continueOnSuccess {
                addLog(.info, "Build successful, stopping agent as configured")
                return false
            }
            
        } catch {
            addLog(.error, "Error in cycle", details: error.localizedDescription)
            noImprovementCount += 1
        }
        
        if noImprovementCount >= maxNoImprovementCount {
            addLog(.warning, "No improvement after multiple attempts", details: "Attempts: \(self.maxNoImprovementCount)")
            return false
        }
        
        return true
    }
}

// MARK: - Log

extension Agent {
    
    private func addLog(_ type: AgentLog.LogType, _ message: String, details: String? = nil) {
        let log = AgentLog(type: type, message: message, details: details)
        logs.append(log)
        
        // 既存のloggerも併用
        switch type {
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .action:
            logger.notice("\(message)")
        }
    }
}
