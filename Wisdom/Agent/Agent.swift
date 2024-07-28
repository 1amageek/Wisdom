//
//  Agent.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import Foundation

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

actor Agent {
    typealias BuildResult = (errorCount: Int, successful: Bool)
    typealias BuildClosure = () async throws -> BuildResult
    typealias GeneratorClosure = (String) async throws -> AgentFileProposal
    typealias FileOperationClosure = (AgentFileOperation) async throws -> Void

    private var buildClosure: BuildClosure
    private var generatorClosure: GeneratorClosure
    private var fileOperationClosure: FileOperationClosure
    private var isRunning: Bool = false
    private var noImprovementCount: Int = 0
    private let maxNoImprovementCount: Int
    private var lastErrorCount: Int = 0
    private let continueOnSuccess: Bool

    init(
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
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        noImprovementCount = 0
        lastErrorCount = Int.max

        var firstRun = true
        while isRunning && (firstRun || noImprovementCount < maxNoImprovementCount) {
            let shouldContinue = await runCycle()
            firstRun = false
            if !shouldContinue {
                break
            }
        }

        isRunning = false
    }

    func stop() {
        isRunning = false
    }

    private func runCycle() async -> Bool {
        do {
            let (currentErrorCount, buildSuccessful) = try await buildClosure()

            if currentErrorCount >= lastErrorCount {
                noImprovementCount += 1
            } else {
                noImprovementCount = 0
            }
            lastErrorCount = currentErrorCount

            let buildStatus = buildSuccessful ? "successful" : "failed"
            let buildErrors = "Build \(buildStatus) with \(currentErrorCount) errors."
            let proposal: AgentFileProposal = try await generatorClosure(buildErrors)

            for operation in proposal.operations {
                try await fileOperationClosure(operation)
            }

            if buildSuccessful && !continueOnSuccess {
                print("Build successful, stopping agent")
                return false
            }

        } catch {
            print("Error in cycle: \(error.localizedDescription)")
            noImprovementCount += 1
        }

        if noImprovementCount >= maxNoImprovementCount {
            print("No improvement after \(maxNoImprovementCount) attempts, stopping agent")
            return false
        }

        return true
    }
}
