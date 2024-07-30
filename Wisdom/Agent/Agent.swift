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

public struct AgentOption {
    let maxNoImprovementCount: Int
    let continueOnSuccess: Bool
    
    public init(maxNoImprovementCount: Int = 5, continueOnSuccess: Bool = true) {
        self.maxNoImprovementCount = maxNoImprovementCount
        self.continueOnSuccess = continueOnSuccess
    }
}

@Observable
public class Agent {
    public static let shared = Agent()
    
    // タイプエイリアス
    public typealias BuildResult = (errorCount: Int, successful: Bool)
    public typealias BuildClosure = () async throws -> BuildResult
    public typealias GenerateClosure = (String, String) async throws -> AgentFileProposal
    public typealias FileOperationClosure = (AgentFileOperation) async throws -> Void
    
    // プロパティ
    private let logger: Logger
    
    public private(set) var logs: [AgentLog] = []
    public private(set) var proposals: [AgentFileProposal] = []
    public private(set) var isRunning: Bool = false
    public private(set) var currentTask: AgentTask?
    
    private init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "team.stamp.Wisdom", category: "Agent")
    }
    
    public func start(
        with message: String,
        option: AgentOption = AgentOption(),
        build: @escaping BuildClosure,
        generate: @escaping GenerateClosure,
        fileOperation: @escaping FileOperationClosure
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
        
        while isRunning && (iterationCount == 0 || noImprovementCount < option.maxNoImprovementCount) {
            iterationCount += 1
            let task = AgentTask(
                message: message,
                build: build,
                generate: generate,
                fileOperation: fileOperation
            )
            currentTask = task
            
            addLog(.info, "[CYCLE:\(iterationCount)] Starting new iteration 🚀")
            
            let result = await task.run { log in
                self.addLog(log.type, log.message, details: log.details, proposalID: log.proposalID, operationID: log.operationID)
            }
            
            switch result {
            case .success(let buildResult):
                if buildResult.errorCount >= lastErrorCount {
                    noImprovementCount += 1
                    addLog(.warning, "[BUILD:\(iterationCount)] No improvement in error count", details: "Current: \(buildResult.errorCount), Last: \(lastErrorCount)")
                } else {
                    noImprovementCount = 0
                    addLog(.info, "[BUILD:\(iterationCount)] Error count improved", details: "From \(lastErrorCount) to \(buildResult.errorCount)")
                }
                lastErrorCount = buildResult.errorCount
                
                if buildResult.successful && !option.continueOnSuccess {
                    addLog(.info, "[CYCLE:\(iterationCount)] Build successful, stopping agent as configured")
                    break
                }
            case .failure(let error):
                addLog(.error, "[CYCLE:\(iterationCount)] Error in cycle", details: error.localizedDescription)
                noImprovementCount += 1
            }
            
            if noImprovementCount >= option.maxNoImprovementCount {
                addLog(.warning, "[CYCLE:\(iterationCount)] No improvement after multiple attempts", details: "Attempts: \(option.maxNoImprovementCount)")
                break
            }
            
            currentTask = nil
        }
        
        addLog(.info, "[AGENT] Agent stopped after \(iterationCount) iterations")
        isRunning = false
        currentTask = nil
    }
    
    public func stop() {
        if isRunning {
            isRunning = false
            currentTask?.stop()
            addLog(.info, "[AGENT] Agent stop requested")
        } else {
            addLog(.info, "[AGENT] Agent stop requested, but agent was not running")
        }
    }
    
    private func addLog(_ type: AgentLog.LogType, _ message: String, details: String? = nil, proposalID: String? = nil, operationID: String? = nil) {
        let log = AgentLog(type: type, message: message, details: details, proposalID: proposalID, operationID: operationID)
        logs.append(log)
        
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

public class AgentTask: Identifiable {
    public let id = UUID()
    public let startTime: Date
    
    private let message: String
    private let build: Agent.BuildClosure
    private let generate: Agent.GenerateClosure
    private let fileOperation: Agent.FileOperationClosure
    
    private var isRunning = true
    
    init(
        message: String,
        build: @escaping Agent.BuildClosure,
        generate: @escaping Agent.GenerateClosure,
        fileOperation: @escaping Agent.FileOperationClosure
    ) {
        self.startTime = Date()
        self.message = message
        self.build = build
        self.generate = generate
        self.fileOperation = fileOperation
    }
    
    func run(logHandler: @escaping (AgentLog) -> Void) async -> Result<Agent.BuildResult, Error> {
        do {
            // Build process
            logHandler(AgentLog(type: .info, message: "[BUILD] Starting build process"))
            let (errorCount, buildSuccessful) = try await build()
            let buildStatus = buildSuccessful ? "successful" : "failed"
            logHandler(AgentLog(type: .info, message: "[BUILD] Build \(buildStatus) with \(errorCount) errors"))
            
            // Generate process
            logHandler(AgentLog(type: .info, message: "[GENERATE] Starting code generation"))
            let buildErrors = "Build \(buildStatus) with \(errorCount) errors."
            let proposal: AgentFileProposal = try await generate(message, buildErrors)
            logHandler(AgentLog(type: .info, message: "[GENERATE] Generated proposal", details: "Operations count: \(proposal.operations.count)", proposalID: proposal.id))
            
            // File operations
            logHandler(AgentLog(type: .info, message: "[FILE_OP] Starting file operations", proposalID: proposal.id))
            for operation in proposal.operations {
                guard isRunning else { break }
                do {
                    try await fileOperation(operation)
                    let fileName = (operation.path as NSString).lastPathComponent
                    logHandler(AgentLog(type: .action, message: "[FILE_OP] Executed file operation",
                                        details: "\(operation.actionType.rawValue) on file: \(fileName)",
                                        proposalID: proposal.id,
                                        operationID: operation.id))
                } catch {
                    let fileName = (operation.path as NSString).lastPathComponent
                    logHandler(AgentLog(type: .error, message: "[FILE_OP] Failed file operation",
                                        details: "\(operation.actionType.rawValue) on file: \(fileName) - Error: \(error.localizedDescription)",
                                        proposalID: proposal.id,
                                        operationID: operation.id))
                }
            }
            logHandler(AgentLog(type: .info, message: "[FILE_OP] Completed all file operations", proposalID: proposal.id))
            
            return .success((errorCount: errorCount, successful: buildSuccessful))
        } catch {
            return .failure(error)
        }
    }
    
    func stop() {
        isRunning = false
    }
}
