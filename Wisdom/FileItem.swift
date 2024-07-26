//
//  FileItem.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import Foundation
import AppKit
import Observation

@Observable
class FileItem: Identifiable {
    
    var id: String { url.absoluteString }
    
    let url: URL
    
    let name: String
    
    let isDirectory: Bool
    
    var children: [FileItem]?
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        self.isDirectory = isDirectory.boolValue
    }
    
    func loadChildren() {
        guard isDirectory else { return }        
        requestDirectoryAccess(at: url) { [weak self] accessibleURL in
            guard let self = self, let url = accessibleURL else { return }

            do {
                let childURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                self.children = childURLs
                    .filter { !$0.lastPathComponent.hasPrefix(".") }
                    .map { FileItem(url: $0) }
                self.children?.sort { $0.name < $1.name }
            } catch {
                print("Error loading children of \(url.path): \(error)")
            }
        }
    }
    
    func requestDirectoryAccess(at url: URL, completion: @escaping (URL?) -> Void) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            do {
                _ = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                completion(url) // アクセス許可がある場合
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == 257 {
                    let openPanel = NSOpenPanel()
                    openPanel.title = "Select Directory"
                    openPanel.showsResizeIndicator = true
                    openPanel.showsHiddenFiles = false
                    openPanel.canChooseFiles = false
                    openPanel.canChooseDirectories = true
                    openPanel.allowsMultipleSelection = false
                    openPanel.begin { result in
                        if result == .OK, let selectedURL = openPanel.url {
                            completion(selectedURL)
                        } else {
                            completion(nil)
                        }
                    }
                } else {
                    print("Error accessing directory \(url.path): \(error)")
                    completion(nil)
                }
            }
        } else {
            completion(nil) // 指定されたURLが存在しないか、ディレクトリでない場合
        }
    }
}

extension FileItem: Hashable {
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
