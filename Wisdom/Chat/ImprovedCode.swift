//
//  ImprovedCode.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import Foundation


struct ImprovedCode: Identifiable, Codable {
    var id: String
    var url: URL
    var language: String
    var code: String
}

extension ImprovedCode {
    
    func extractCode() throws -> (URL, String) {
        guard let urlLine = code.components(separatedBy: .newlines).first,
              urlLine.hasPrefix("URL: "),
              let url = URL(string: String(urlLine.dropFirst(5))) else {
            throw NSError(domain: "ImprovedCode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format in improved code"])
        }

        let codeLines = code.components(separatedBy: .newlines)
        guard let startIndex = codeLines.firstIndex(where: { $0.hasPrefix("```swift:") }),
              let endIndex = codeLines.lastIndex(where: { $0 == "```" }),
              startIndex < endIndex else {
            throw NSError(domain: "ImprovedCode", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid code block format in improved code"])
        }

        let extractedCode = codeLines[(startIndex + 1)..<endIndex].joined(separator: "\n")
        return (url, extractedCode)
    }
}
