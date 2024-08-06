//
//  ServerSettingView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import SwiftUI

struct ServerSettingView: View {
    @Environment(AppState.self) var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var hostname: String = "0.0.0.0"
    @State private var port: Int = 6060
    @State private var publicPort: Int = 6060
    @State private var publicIP: String = "Fetching..."
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Local Server Settings")) {
                    TextField("Host", text: $hostname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Port", value: $port, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Public Access Settings")) {
                    TextField("Public Port", value: $publicPort, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    HStack {
                        Text("Public IP:")
                        Spacer()
                        Text(publicIP)
                    }
                }
                
                Section(header: Text("Info")) {
                    Text("Use '0.0.0.0' to allow connections from any IP address. Ensure your router is configured to forward the public port to the local port.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Server Settings")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Reset") {
                    Task {
                        await ServerManager.shared.setHostname("0.0.0.0")
                        await ServerManager.shared.setPort(6060)
                        await ServerManager.shared.setPublicPort(6060)
                        hostname = "0.0.0.0"
                        port = 6060
                        publicPort = 6060
                    }
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button {
                    Task {
                        await ServerManager.shared.setHostname(hostname)
                        await ServerManager.shared.setPort(port)
                        await ServerManager.shared.setPublicPort(publicPort)
                        dismiss()
                    }
                } label: {
                    Text("OK")
                        .padding(.horizontal, 14)
                }
            }
            .padding()
        }
        .frame(width: 300)
        .onAppear {
            Task {
                hostname = await ServerManager.shared.hostname
                port = await ServerManager.shared.port
                publicPort = await ServerManager.shared.publicPort
                if let ip = await ServerManager.shared.getPublicIPAddress() {
                    publicIP = ip
                } else {
                    publicIP = "Unable to fetch"
                }
            }
        }
    }
}

#Preview {
    ServerSettingView()
        .environment(AppState())
}
