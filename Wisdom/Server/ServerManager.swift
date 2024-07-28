//
//  ServerManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import Foundation
import Vapor

actor ServerManager {
    private var app: Application?
    private weak var appState: AppState?
    private weak var buildManager: BuildManager?
    private var isRunning = false
    var hostname: String
    var port: Int
    
    init(hostname: String = "127.0.0.1", port: Int = 6060) {
        self.hostname = hostname
        self.port = port
    }
    
    func isServerRunning() -> Bool {
        return isRunning
    }
    
    func setDelegate(_ appState: AppState, buildManager: BuildManager) {
        self.appState = appState
        self.buildManager = buildManager
    }
    
    func setHostname(_ newHostname: String) {
        guard !isRunning else {
            print("Cannot change hostname while server is running")
            return
        }
        self.hostname = newHostname
        print("Host", self.hostname)
    }
    
    func setPort(_ newPort: Int) {
        guard !isRunning else {
            print("Cannot change port while server is running")
            return
        }
        self.port = newPort
        print("Port", self.port)
    }
    
    func start() async throws {
        guard !isRunning else { return }
        
        do {
            print("Attempting to start server...")
            
            var env = Environment.development
            env.arguments = ["serve"]
            
            let app = Application(env)
            app.http.server.configuration.hostname = self.hostname
            app.http.server.configuration.port = self.port
            configureRoutes(app)
            self.app = app
            
            Task.detached {
                do {
                    try await app.execute()
                } catch {
                    print("Server error: \(error)")
                }
            }
            self.isRunning = true
            print("Server started successfully on \(self.hostname):\(self.port)")
        } catch {
            print("Failed to start server: \(error)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain), code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
            }
            self.app = nil
            self.isRunning = false
            throw error
        }
    }
    
    func stop() async throws {
        guard isRunning, let app = app else { return }
        
        do {
            print("Attempting to stop server...")
            try await app.asyncShutdown()
            self.app = nil
            self.isRunning = false
            print("Server stopped successfully")
        } catch {
            print("Failed to stop server: \(error)")
            throw error
        }
    }
    
    private func configureRoutes(_ app: Application) {
        
        app.get("/") { req -> String in
            return "OK"
        }
        
        app.get("errors") { req -> String in
            guard let url = self.appState?.rootItem?.url else { return "" }
            return self.buildManager?.errors(url) ?? ""
        }
        
        app.get("context") { req -> String in
            return self.appState?.context ?? ""
        }
        
        app.get("files", ":filename") { req -> Response in
            guard let filename = req.parameters.get("filename"),
                  let file = self.appState?.files.first(where: { $0.url.lastPathComponent == filename }) else {
                throw Abort(.notFound)
            }
            
            return Response(status: .ok, body: .init(string: file.content))
        }
    }
    
    deinit {
        if isRunning {
            Task {
                try? await stop()
            }
        }
    }
}
