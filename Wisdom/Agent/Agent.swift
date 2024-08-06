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
    
    private enum CodingKeys: String, CodingKey {
        case id, language, actionType, path, content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        language = try container.decode(String.self, forKey: .language)
        actionType = try container.decode(AgentFileOperationType.self, forKey: .actionType)
        path = try container.decode(String.self, forKey: .path)
        
        if let base64Content = try container.decodeIfPresent(String.self, forKey: .content) {
            if let decodedData = Data(base64Encoded: base64Content),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                content = decodedString
            } else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Failed to decode BASE64 content")
            }
        } else {
            content = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(language, forKey: .language)
        try container.encode(actionType, forKey: .actionType)
        try container.encode(path, forKey: .path)
        
        if let content = content {
            let base64Content = Data(content.utf8).base64EncodedString()
            try container.encode(base64Content, forKey: .content)
        }
    }
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
    let generateTimeout: TimeInterval?
    
    public init(maxNoImprovementCount: Int = 5,
                continueOnSuccess: Bool = true,
                generateTimeout: TimeInterval? = 60) {
        self.maxNoImprovementCount = maxNoImprovementCount
        self.continueOnSuccess = continueOnSuccess
        self.generateTimeout = generateTimeout
    }
}

struct TimeoutError: Error {
    let seconds: TimeInterval
    
    var localizedDescription: String {
        return "Operation timed out after \(seconds) seconds"
    }
}

enum AgentError: Error {
    case buildFailed(String)
    case generateFailed(String)
    case fileOperationFailed(String)
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
                fileOperation: fileOperation,
                option: option
            )
            currentTask = task
            
            addLog(.info, "[CYCLE:\(iterationCount)] Starting new iteration 🚀")
            
            do {
                let buildResult = try await task.run(timeout: option.generateTimeout) { log in
                    self.addLog(log.type, log.message, details: log.details, proposalID: log.proposalID, operationID: log.operationID)
                }
                
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
            } catch {
                addLog(.error, "[CYCLE:\(iterationCount)] Error in cycle", details: error.localizedDescription)
                if let agentError = error as? AgentError {
                    switch agentError {
                    case .buildFailed(let errorDetails):
                        addLog(.error, "[BUILD:\(iterationCount)] Build failed", details: errorDetails)
                    case .generateFailed(let errorDetails):
                        addLog(.error, "[GENERATE:\(iterationCount)] Generate failed", details: errorDetails)
                    case .fileOperationFailed(let errorDetails):
                        addLog(.error, "[FILE_OP:\(iterationCount)] File operation failed", details: errorDetails)
                    }
                }
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
    
    private let option: AgentOption
    private let message: String
    private let build: Agent.BuildClosure
    private let generate: Agent.GenerateClosure
    private let fileOperation: Agent.FileOperationClosure
    
    private var isRunning = true
    
    init(
        message: String,
        build: @escaping Agent.BuildClosure,
        generate: @escaping Agent.GenerateClosure,
        fileOperation: @escaping Agent.FileOperationClosure,
        option: AgentOption) {
            self.startTime = Date()
            self.message = message
            self.build = build
            self.generate = generate
            self.fileOperation = fileOperation
            self.option = option
        }
    
    func run(timeout: TimeInterval?, logHandler: @escaping (AgentLog) -> Void) async throws -> Agent.BuildResult {
        // Build process
        logHandler(AgentLog(type: .info, message: "[BUILD] Starting build process"))
        let (errorCount, buildSuccessful) = try await build()
        let buildStatus = buildSuccessful ? "successful" : "failed"
        logHandler(AgentLog(type: .info, message: "[BUILD] Build \(buildStatus) with \(errorCount) errors"))
        
        // Generate process
        logHandler(AgentLog(type: .info, message: "[GENERATE] Starting code generation"))
        let buildErrors = "Build \(buildStatus) with \(errorCount) errors."
        let proposal: AgentFileProposal
        do {
            let startTime = Date()
            if let timeout = timeout {
                proposal = try await withTimeout(seconds: timeout) {
                    try await self.generate(self.message, buildErrors)
                }
            } else {
                proposal = try await self.generate(self.message, buildErrors)
            }
            let duration = Date().timeIntervalSince(startTime)
            logHandler(AgentLog(type: .info, message: "[GENERATE] Generated proposal",
                                details: "Duration: \(String(format: "%.2f", duration))s, Operations count: \(proposal.operations.count)",
                                proposalID: proposal.id))
            
            logHandler(AgentLog(type: .info, message: "[GENERATE] Proposal content", details: nil))
        } catch let error as TimeoutError {
            logHandler(AgentLog(type: .error, message: "[GENERATE] Timeout error", details: error.localizedDescription))
            throw AgentError.generateFailed("Generation timed out after \(timeout ?? 0) seconds")
        } catch let error as DecodingError {
            logHandler(AgentLog(type: .error, message: "[GENERATE] Decoding error", details: "Error: \(error.localizedDescription)"))
            logHandler(AgentLog(type: .error, message: "[GENERATE] Full decoding error", details: String(describing: error)))
            throw AgentError.generateFailed("Decoding failed: Possible data mismatch or incomplete response from LLM")
        } catch {
            logHandler(AgentLog(type: .error, message: "[GENERATE] Unexpected error", details: "Error: \(error.localizedDescription)"))
            logHandler(AgentLog(type: .error, message: "[GENERATE] Full error details", details: String(describing: error)))
            throw AgentError.generateFailed("Generation failed: \(error.localizedDescription)")
        }
        
        // Validate proposal
        if proposal.operations.isEmpty {
            logHandler(AgentLog(type: .warning, message: "[GENERATE] Empty proposal", details: "LLM returned no operations"))
            throw AgentError.generateFailed("LLM returned an empty proposal")
        }
        
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
                throw AgentError.fileOperationFailed("File operation failed for \(fileName): \(error.localizedDescription)")
            }
        }
        logHandler(AgentLog(type: .info, message: "[FILE_OP] Completed all file operations", proposalID: proposal.id))
        
        return (errorCount: errorCount, successful: buildSuccessful)
    }
    
    func stop() {
        isRunning = false
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(seconds: seconds)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
