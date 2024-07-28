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
    public typealias GenerateClosure = (String, String) async throws -> AgentFileProposal
    public typealias FileOperationClosure = (AgentFileOperation) async throws -> Void
    
    // プロパティ
    private let maxNoImprovementCount: Int
    private let continueOnSuccess: Bool
    private let logger: Logger
    
    public private(set) var logs: [AgentLog] = []
    public private(set) var isRunning: Bool = false
    
    public init(
        maxNoImprovementCount: Int = 5,
        continueOnSuccess: Bool = true
    ) {
        self.maxNoImprovementCount = maxNoImprovementCount
        self.continueOnSuccess = continueOnSuccess
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.Wisdom", category: "Agent")
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
          
          addLog(.info, "[AGENT] Agent started with message: \(message)")
          
          func runCycle() async -> Bool {
              do {
                  // Build process
                  addLog(.info, "[BUILD] Starting build process")
                  let (currentErrorCount, buildSuccessful) = try await build()
                  let buildStatus = buildSuccessful ? "successful" : "failed"
                  addLog(.info, "[BUILD] Build \(buildStatus) with \(currentErrorCount) errors")
                  
                  if currentErrorCount >= lastErrorCount {
                      noImprovementCount += 1
                      addLog(.warning, "[BUILD] No improvement in error count", details: "Current: \(currentErrorCount), Last: \(lastErrorCount)")
                  } else {
                      noImprovementCount = 0
                      addLog(.info, "[BUILD] Error count improved", details: "From \(lastErrorCount) to \(currentErrorCount)")
                  }
                  lastErrorCount = currentErrorCount
                  
                  // Generate process
                  addLog(.info, "[GENERATE] Starting code generation")
                  let buildErrors = "Build \(buildStatus) with \(currentErrorCount) errors."
                  do {
                      let proposal: AgentFileProposal = try await generate(message, buildErrors)
                      addLog(.info, "[GENERATE] Generated proposal", details: "Operations count: \(proposal.operations.count)")
                      
                      // File operations
                      addLog(.info, "[FILE_OP] Starting file operations")
                      for operation in proposal.operations {
                          do {
                              try await fileOperation(operation)
                              addLog(.action, "[FILE_OP] Executed file operation", details: "\(operation.actionType.rawValue) on \(operation.path)")
                          } catch {
                              addLog(.error, "[FILE_OP] Failed file operation", details: "\(operation.actionType.rawValue) on \(operation.path) - Error: \(error.localizedDescription)")
                          }
                      }
                      addLog(.info, "[FILE_OP] Completed all file operations")
                  } catch {
                      addLog(.error, "[GENERATE] Failed to generate proposal", details: error.localizedDescription)
                      return false // Stop the cycle if generate fails
                  }
                  
                  if buildSuccessful && !continueOnSuccess {
                      addLog(.info, "[CYCLE] Build successful, stopping agent as configured")
                      return false
                  }
                  
              } catch {
                  addLog(.error, "[CYCLE] Error in cycle", details: error.localizedDescription)
                  noImprovementCount += 1
              }
              
              if noImprovementCount >= maxNoImprovementCount {
                  addLog(.warning, "[CYCLE] No improvement after multiple attempts", details: "Attempts: \(self.maxNoImprovementCount)")
                  return false
              }
              
              return true
          }
          
          var firstRun = true
          while isRunning && (firstRun || noImprovementCount < maxNoImprovementCount) {
              let shouldContinue = await runCycle()
              firstRun = false
              if !shouldContinue {
                  addLog(.info, "[CYCLE] Cycle completed, breaking loop")
                  break
              }
          }
          
          addLog(.info, "[AGENT] Agent stopped")
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
}

// MARK: - Log

extension Agent {
    private func addLog(_ type: AgentLog.LogType, _ message: String, details: String? = nil) {
        let log = AgentLog(type: type, message: message, details: details)
        logs.append(log)
        
        // 既存のloggerも併用し、detailsも表示
        let logMessage = details.map { "\(message) - Details: \($0)" } ?? message
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
