//
//  FileTypeSelectionView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import SwiftUI

struct FileTypeSelectionView: View {
    @Environment(AppState.self) var appState: AppState
    @State private var selectedTypes: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Select File Types")
                .font(.title)
                .padding()
            
            List {
                ForEach(appState.availableFileTypes, id: \.self) { fileType in
                    Button(action: {
                        if selectedTypes.contains(fileType) {
                            selectedTypes.remove(fileType)
                        } else {
                            selectedTypes.insert(fileType)
                        }
                    }) {
                        HStack {
                            Text(fileType)
                            Spacer()
                            if selectedTypes.contains(fileType) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Done") {
                    appState.updateSelectedFileTypes(Array(selectedTypes))
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .onAppear {
            selectedTypes = Set(appState.selectedFileTypes)
        }
    }
}

#Preview {
    FileTypeSelectionView()
}
