//
//  CommandSettingView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import SwiftUI

struct CommandSettingView: View {
    @Environment(BuildManager.self) private var buildManager: BuildManager
    @State private var customCommands: [String: String] = [:]
    @State private var newPresetName: String = ""
    @State private var newPresetCommand: String = ""
    @State private var selectedConfiguration: String = "Debug"
    @State private var enableParallelBuilding: Bool = true
    @State private var treatWarningsAsErrors: Bool = false

    private let configurations = ["Debug", "Release"]

    var body: some View {
        Form {
            Section(header: Text("Current Project")) {
                Text(buildManager.currentProjectURL?.lastPathComponent ?? "No project selected")
                    .font(.headline)
                Text("Type: \(buildManager.detectedProjects[buildManager.currentProjectURL ?? URL(fileURLWithPath: "")]?.rawValue ?? "Unknown")")
                Text("Build Tool: \(buildManager.buildTool == .spm ? "Swift Package Manager" : "Xcode")")
            }

            Section(header: Text("Current Build Command")) {
                Text(buildManager.buildCommand)
                    .font(.system(.body, design: .monospaced))
            }
            
            Section(header: Text("Configuration")) {
                Picker("Configuration", selection: $selectedConfiguration) {
                    ForEach(configurations, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: selectedConfiguration) { _, newValue in
                    buildManager.schemaManager.setSelectedSchema(newValue)
                }
            }
            
            Section(header: Text("Custom Command Presets")) {
                ForEach(Array(customCommands.keys), id: \.self) { preset in
                    HStack {
                        Text(preset)
                        Spacer()
                        Button("Use") {
                            buildManager.setCustomBuildCommand(customCommands[preset])
                        }
                        Button("Delete") {
                            customCommands.removeValue(forKey: preset)
                        }
                    }
                }
                
                HStack {
                    TextField("Preset Name", text: $newPresetName)
                    TextField("Command", text: $newPresetCommand)
                    Button("Add") {
                        if !newPresetName.isEmpty && !newPresetCommand.isEmpty {
                            customCommands[newPresetName] = newPresetCommand
                            newPresetName = ""
                            newPresetCommand = ""
                        }
                    }
                }
            }
            
            Section(header: Text("Advanced Options")) {
                if buildManager.buildTool == .xcodebuild {
                    Toggle("Enable Parallel Building", isOn: $enableParallelBuilding)
                        .onChange(of: enableParallelBuilding) { _, newValue in
                            updateBuildCommand()
                        }
                    Toggle("Treat Warnings as Errors", isOn: $treatWarningsAsErrors)
                        .onChange(of: treatWarningsAsErrors) { _, newValue in
                            updateBuildCommand()
                        }
                } else if buildManager.buildTool == .spm {
                    // SPM specific options can be added here
                    Text("SPM advanced options coming soon")
                }
            }
        }
        .navigationTitle("Build Settings")
        .onAppear {
            selectedConfiguration = buildManager.schemaManager.selectedSchema ?? "Debug"
        }
    }

    private func updateBuildCommand() {
        var command = buildManager.buildTool == .spm ? "swift build" : "xcodebuild"
        
        if buildManager.buildTool == .xcodebuild {
            command += " -configuration \(selectedConfiguration)"
            if enableParallelBuilding {
                command += " -parallelizeTargets"
            }
            if treatWarningsAsErrors {
                command += " GCC_TREAT_WARNINGS_AS_ERRORS=YES"
            }
        } else {
            command += " -c \(selectedConfiguration)"
        }

        buildManager.setCustomBuildCommand(command)
    }
}

#Preview {
    CommandSettingView()
        .environment(BuildManager.shared)
}
