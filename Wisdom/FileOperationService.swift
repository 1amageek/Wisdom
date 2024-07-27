//
//  FileOperationService.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import Foundation

class FileOperationService: NSObject, FileOperationServiceProtocol {
    func writeFile(atPath path: String, content: String, reply: @escaping (Bool, Error?) -> Void) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            reply(true, nil)
        } catch {
            reply(false, error)
        }
    }

    func readFile(atPath path: String, reply: @escaping (String?, Error?) -> Void) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            reply(content, nil)
        } catch {
            reply(nil, error)
        }
    }
}

@objc(FileOperationServiceProtocol)
protocol FileOperationServiceProtocol {
    func writeFile(atPath path: String, content: String, reply: @escaping (Bool, Error?) -> Void)
    func readFile(atPath path: String, reply: @escaping (String?, Error?) -> Void)
}
