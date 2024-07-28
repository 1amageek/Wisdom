//
//  Functions.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/24.
//

import Foundation

public class Functions {
    
    public static let shared = Functions()
    
    private let baseURL = "http://localhost:5001/x-package/asia-northeast1"
    
    private init() {}
    
    // カスタムJSONDecoderを作成するメソッド
    static func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // ミリ秒が含まれていない場合のフォールバック
            dateFormatter.formatOptions = [.withInternetDateTime]
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return decoder
    }
    
    func callFunction(_ name: String, parameters: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(name)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status Code: \(httpResponse.statusCode)")
        }
        print("Response Data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
        
        return data
    }
    
    func requirements(userID: String, packageID: String, threadID: String, message: String) async throws -> ChatMessage {
        let parameters: [String: Any] = [
            "userID": userID,
            "packageID": packageID,
            "threadID": threadID,
            "message": message
        ]
        let data = try await callFunction("requirements", parameters: parameters)    
        let decoder = Functions.createDecoder()
        
        do {
            let chatMessage = try decoder.decode(ChatMessage.self, from: data)
            print("Successfully decoded ChatMessage: \(chatMessage)")
            return chatMessage
        } catch {
            print("Decoding Error: \(error)")
            throw error
        }
    }
    
    func message(userID: String, packageID: String, threadID: String, message: String) async throws -> (ChatMessage, [AgentAction]) {
        let parameters: [String: Any] = [
            "message": message
        ]
        let data = try await callFunction("message", parameters: parameters)
        let decoder = Functions.createDecoder()
        
        do {
            let improveMessage = try decoder.decode(ImproveMessage.self, from: data)
            let operations: [AgentAction] = improveMessage.operations
            let codeContents: [CodeContent] = operations.map { CodeContent(id: $0.id, path: $0.path) }
            let chatMessage = ChatMessage(id: improveMessage.id, content: [.init(text: improveMessage.text, codes: codeContents)], role: .model, timestamp: improveMessage.timestamp)
            print("Successfully decoded ChatMessage: \(chatMessage)")
            return (chatMessage, operations)
        } catch {
            print("Decoding Error: \(error)")
            throw error
        }
    }
    
    func improve(userID: String, packageID: String, message: String) async throws -> AgentFileProposal {
        let parameters: [String: Any] = [
            "message": message
        ]
        let data = try await callFunction("improve", parameters: parameters)
        let decoder = Functions.createDecoder()
        
        do {
            let proposal = try decoder.decode(AgentFileProposal.self, from: data)
            print("Successfully decoded proposal: \(proposal)")
            return proposal
        } catch {
            print("Decoding Error: \(error)")
            throw error
        }
    }
    
//    func spec(userID: String, packageID: String, message: String, dependencies: String) async throws -> ProjectSpec {
//        let parameters: [String: Any] = [
//            "userID": userID,
//            "packageID": packageID,
//            "message": message,
//            "dependencies": dependencies
//        ]
//        let data = try await callFunction("spec", parameters: parameters)
//        let decoder = Functions.createDecoder()
//        
//        do {
//            let spec = try decoder.decode(ProjectSpec.self, from: data)
//            return spec
//        } catch {
//            print("Decoding Error: \(error)")
//            throw error
//        }
//    }
//    
//    func gencode(userID: String, packageID: String, spec: FileSpec, dependencies: String) async throws -> String {
//        let parameters: [String: Any] = [
//            "userID": userID,
//            "packageID": packageID,
//            "spec": spec.toDictionary(),
//            "dependencies": dependencies
//        ]
//        print("----", parameters)
//        let data = try await callFunction("gencode", parameters: parameters)
//        
//        guard let codeString = String(data: data, encoding: .utf8) else {
//            throw NSError(domain: "Gencode Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response data to string"])
//        }
//        
//        return codeString
//    }
}
