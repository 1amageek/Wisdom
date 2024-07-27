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
    
    @State private var hostname: String = "127.0.0.1"
    @State private var port: Int = 6060
    
    init() {
        
    }
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none  // カンマを入れない設定
        return formatter
    }
    
    var body: some View {
        Form {
            Section(header: Text("Server Settings")) {
                TextField("Host", text: $hostname)
                TextField("Port", value: $port, formatter: numberFormatter)
            }
        }
        .padding()
        .navigationTitle("Server Settings")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Reset") {
                    Task {
                        await appState.serverManager.setHostname("127.0.0.1")
                        await appState.serverManager.setPort(6060)
                    }
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button {
                    Task {
                        await appState.serverManager.setHostname(hostname)
                        await appState.serverManager.setPort(port)
                        dismiss()
                    }
                } label: {
                    Text("OK")
                        .padding(.horizontal, 14)
                }
                
            }
            .padding()
        }
        .frame(width: 260)
    }
}


#Preview {
    ServerSettingView()
        .environment(AppState())
}
