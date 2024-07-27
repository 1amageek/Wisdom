//
//  DirectoryManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import Foundation

@Observable
class DirectoryManager {
    
    enum OperationError: Error {
        case bookmarkResolutionFailed
        case securityScopedResourceAccessFailed
        case bookmarkCreationFailed
        case noSavedDirectory
    }
    
    private var securityScopedBookmark: Data?
    
    func loadSavedDirectory() -> URL? {
        if let bookmarkData = UserDefaults.standard.data(forKey: "RootDirectoryBookmark") {
            do {
                let resolvedURL = try resolveAndAccessBookmark(bookmarkData)
                print("Loaded bookmarked directory: \(resolvedURL.path)")
                return resolvedURL
            } catch {
                print("Error resolving bookmark: \(error.localizedDescription)")
                self.securityScopedBookmark = nil
                return loadFallbackDirectory()
            }
        } else {
            return loadFallbackDirectory()
        }
    }
    
    func setDirectory(_ url: URL) throws -> URL {
        do {
            let bookmarkData = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            self.securityScopedBookmark = bookmarkData
            
            let resolvedURL = try resolveAndAccessBookmark(bookmarkData)
            
            UserDefaults.standard.set(resolvedURL.path, forKey: "LastOpenedDirectory")
            UserDefaults.standard.set(bookmarkData, forKey: "RootDirectoryBookmark")
            
            print("Directory set and bookmarked successfully: \(resolvedURL.path)")
            return resolvedURL
        } catch {
            print("Error setting URL and creating bookmark: \(error.localizedDescription)")
            throw OperationError.bookmarkCreationFailed
        }
    }
    
    private func loadFallbackDirectory() -> URL? {
        if let lastPath = UserDefaults.standard.string(forKey: "LastOpenedDirectory"),
           let url = URL(string: lastPath) {
            return url
        } else {
            print("No saved directory found")
            return nil
        }
    }
    
    private func resolveAndAccessBookmark(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        
        if isStale {
            let newBookmarkData = try resolvedURL.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            self.securityScopedBookmark = newBookmarkData
        }
        
        if !resolvedURL.startAccessingSecurityScopedResource() {
            throw OperationError.securityScopedResourceAccessFailed
        }
        
        return resolvedURL
    }
    
    func stopAccessingSecurityScopedResource(for url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
