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
    @State private var selectedSchema: String = ""
    @State private var enableParallelBuilding: Bool = true
    @State private var treatWarningsAsErrors: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Current Project")) {
                Text(buildManager.currentProjectURL?.lastPathComponent ?? "No project selected")
                    .font(.headline)
                Text("Type: \(buildManager.detectedProjects[buildManager.currentProjectURL ?? URL(fileURLWithPath: "")]?.rawValue ?? "Unknown")")
                Text("Build Tool: \(buildManager.buildTool == .spm ? "Swift Package Manager" : (buildManager.buildTool == .xcodebuild ? "Xcode" : "npm"))")
            }

            Section(header: Text("Current Build Command")) {
                Text(buildManager.buildCommand)
                    .font(.system(.body, design: .monospaced))
            }
            
            switch buildManager.detectedProjects[buildManager.currentProjectURL ?? URL(fileURLWithPath: "")] {
            case .spm:
                Section(header: Text("Swift Package Manager Targets")) {
                    schemaPicker
                }
            case .xcodeproj, .xcworkspace:
                Section(header: Text("Xcode Schemes")) {
                    schemaPicker
                }
            case .nodejs:
                Section(header: Text("NPM Scripts")) {
                    schemaPicker
                }
            case .unknown, .none:
                Text("Unknown or unsupported project type")
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
                } else if buildManager.buildTool == .npm {
                    // npm specific options can be added here
                    Text("npm advanced options coming soon")
                }
            }
        }
        .navigationTitle("Build Settings")
        .onAppear {
            selectedSchema = buildManager.schemaManager.selectedSchema ?? ""
            Task {
                await buildManager.updateBuildSettingsFromProject()
            }
        }
    }

    private var schemaPicker: some View {
        Picker("Target/Scheme/Script", selection: $selectedSchema) {
            ForEach(buildManager.schemaManager.availableSchemas, id: \.self) { schema in
                Text(schema).tag(schema)
            }
        }
        .onChange(of: selectedSchema) { _, newValue in
            buildManager.schemaManager.setSelectedSchema(newValue)
            buildManager.updateBuildCommand()
        }
    }

    private func updateBuildCommand() {
        var command = buildManager.buildCommand
        
        if buildManager.buildTool == .xcodebuild {
            if enableParallelBuilding {
                command += " -parallelizeTargets"
            }
            if treatWarningsAsErrors {
                command += " GCC_TREAT_WARNINGS_AS_ERRORS=YES"
            }
        }

        buildManager.setCustomBuildCommand(command)
    }
}

#Preview {
    CommandSettingView()
        .environment(BuildManager.shared)
}
