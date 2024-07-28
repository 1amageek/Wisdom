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
    public let actionType: AgentFileOperationType
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
    public var proposalID: String?
    public var operationID: String?
    
    public enum LogType: String, Codable {
        case info
        case warning
        case error
        case action
    }
    
    init(type: LogType, message: String, details: String? = nil, proposalID: String? = nil, operationID: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.message = message
        self.details = details
        self.proposalID = proposalID
        self.operationID = operationID
    }
}

@Observable
public class Agent {
    
    // タイプエイリアス
    public typealias BuildResult = (errorCount: Int, successful: Bool)
    public typealias BuildClosure = () async throws -> BuildResult
    public typealias GenerateClosure = (String, String) async throws -> AgentFileProposal
    public typealias FileOperationClosure = (AgentFileOperation) async throws -> Void
    
    // プロパティ
    private let maxNoImprovementCount: Int
    private let continueOnSuccess: Bool
    private let logger: Logger
    
    public private(set) var logs: [AgentLog] = []
    public private(set) var isRunning: Bool = false
    public private(set) var proposals: [AgentFileProposal] = []
    
    public init(
        maxNoImprovementCount: Int = 5,
        continueOnSuccess: Bool = true
    ) {
        self.maxNoImprovementCount = maxNoImprovementCount
        self.continueOnSuccess = continueOnSuccess
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "team.stamp.Wisdom", category: "Agent")
    }
    
    public func start(
        with message: String,
        build: BuildClosure,
        generate: GenerateClosure,
        fileOperation: FileOperationClosure
    ) async {
        guard !isRunning else {
            addLog(.warning, "[AGENT] Agent is already running, ignoring start request")
            return
        }
        
        isRunning = true
        var noImprovementCount = 0
        var lastErrorCount = Int.max
        var iterationCount = 0
        
        addLog(.info, "[AGENT] Agent started with message: \(message)")
        
        func runCycle() async -> Bool {
            iterationCount += 1
            addLog(.info, "[CYCLE:\(iterationCount)] Starting new iteration 🚀")
            do {
                // Build process
                addLog(.info, "[BUILD:\(iterationCount)] Starting build process")
                let (currentErrorCount, buildSuccessful) = try await build()
                let buildStatus = buildSuccessful ? "successful" : "failed"
                addLog(.info, "[BUILD:\(iterationCount)] Build \(buildStatus) with \(currentErrorCount) errors")
                
                if currentErrorCount >= lastErrorCount {
                    noImprovementCount += 1
                    addLog(.warning, "[BUILD:\(iterationCount)] No improvement in error count", details: "Current: \(currentErrorCount), Last: \(lastErrorCount)")
                } else {
                    noImprovementCount = 0
                    addLog(.info, "[BUILD:\(iterationCount)] Error count improved", details: "From \(lastErrorCount) to \(currentErrorCount)")
                }
                lastErrorCount = currentErrorCount
                
                // Generate process
                addLog(.info, "[GENERATE:\(iterationCount)] Starting code generation")
                let buildErrors = "Build \(buildStatus) with \(currentErrorCount) errors."
                do {
                    let proposal: AgentFileProposal = try await generate(message, buildErrors)
                    addProposal(proposal)
                    addLog(.info, "[GENERATE:\(iterationCount)] Generated proposal", details: "Operations count: \(proposal.operations.count)", proposalID: proposal.id)
                    
                    // File operations
                    addLog(.info, "[FILE_OP:\(iterationCount)] Starting file operations", proposalID: proposal.id)
                    for operation in proposal.operations {
                        do {
                            try await fileOperation(operation)
                            let fileName = extractFileName(from: operation.path)
                            addLog(.action, "[FILE_OP:\(iterationCount)] Executed file operation",
                                   details: "\(operation.actionType.rawValue) on file: \(fileName)",
                                   proposalID: proposal.id,
                                   operationID: operation.id)
                        } catch {
                            let fileName = extractFileName(from: operation.path)
                            addLog(.error, "[FILE_OP:\(iterationCount)] Failed file operation",
                                   details: "\(operation.actionType.rawValue) on file: \(fileName) - Error: \(error.localizedDescription)",
                                   proposalID: proposal.id,
                                   operationID: operation.id)
                        }
                    }
                    addLog(.info, "[FILE_OP:\(iterationCount)] Completed all file operations", proposalID: proposal.id)
                } catch {
                    addLog(.error, "[GENERATE:\(iterationCount)] Failed to generate proposal", details: error.localizedDescription)
                    return false // Stop the cycle if generate fails
                }
                
                if buildSuccessful && !continueOnSuccess {
                    addLog(.info, "[CYCLE:\(iterationCount)] Build successful, stopping agent as configured")
                    return false
                }
                
            } catch {
                addLog(.error, "[CYCLE:\(iterationCount)] Error in cycle", details: error.localizedDescription)
                noImprovementCount += 1
            }
            
            if noImprovementCount >= maxNoImprovementCount {
                addLog(.warning, "[CYCLE:\(iterationCount)] No improvement after multiple attempts", details: "Attempts: \(self.maxNoImprovementCount)")
                return false
            }
            
            return true
        }
        
        while isRunning && (iterationCount == 0 || noImprovementCount < maxNoImprovementCount) {
            let shouldContinue = await runCycle()
            if !shouldContinue {
                addLog(.info, "[CYCLE:\(iterationCount)] Cycle completed, breaking loop")
                break
            }
        }
        
        addLog(.info, "[AGENT] Agent stopped after \(iterationCount) iterations")
        isRunning = false
    }
    
    public func stop() {
        if isRunning {
            addLog(.info, "[AGENT] Agent stop requested")
            isRunning = false
        } else {
            addLog(.info, "[AGENT] Agent stop requested, but agent was not running")
        }
    }
    
    private func extractFileName(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }
}

// MARK: - Proposal

extension Agent {
    
    private func addProposal(_ proposal: AgentFileProposal) {
        proposals.append(proposal)
    }
    
    public func getProposal(id: String) -> AgentFileProposal? {
        return proposals.first { $0.id == id }
    }
    
    public func getLatestProposal() -> AgentFileProposal? {
        return proposals.last
    }
    
    public func getOperation(id: String) -> AgentFileOperation? {
        for proposal in proposals {
            if let operation = proposal.operations.first(where: { $0.id == id }) {
                return operation
            }
        }
        return nil
    }
}

// MARK: - Log

extension Agent {
    private func addLog(_ type: AgentLog.LogType, _ message: String, details: String? = nil, proposalID: String? = nil, operationID: String? = nil) {
        let log = AgentLog(type: type, message: message, details: details, proposalID: proposalID, operationID: operationID)
        logs.append(log)
        
        // 既存のloggerも併用し、details、proposalID、operationIDも表示
        var logMessage = message
        if let details = details {
            logMessage += " - Details: \(details)"
        }
        if let proposalID = proposalID {
            logMessage += " - ProposalID: \(proposalID)"
        }
        if let operationID = operationID {
            logMessage += " - OperationID: \(operationID)"
        }
        
        switch type {
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .action:
            logger.notice("\(logMessage)")
        }
    }
}
