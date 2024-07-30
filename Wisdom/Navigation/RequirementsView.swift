//
//  RequirementsView.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI

struct RequirementsView<Content: View>: View {
    
    let rootItem: FileItem?
    
    @Environment(AppState.self) var appState: AppState
    
    @Binding var selection: Set<FileItem>
    
    @State var isPresented: Bool = false
    @State private var newFileName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var content: () -> Content
    
    init(rootItem: FileItem?, selection: Binding<Set<FileItem>>, @ViewBuilder content: @escaping () -> Content) {
        if let url = rootItem?.url {
            do {
                let wisdomURL = try RequirementsManager.ensureWisdomDirectory(at: url)
                self.rootItem = FileItem(url: wisdomURL)
                print("Directory created successfully")
            } catch {
                print("Error creating directory: \(error)")
                self.rootItem = nil
            }
        } else {
            self.rootItem = nil
        }
        self._selection = selection
        self.content = content
    }
    
    var body: some View {
        ZStack {
            if let rootItem = rootItem {
                List(selection: $selection) {
                    OutlineGroup(rootItem, children: \.children) { item in
                        FileItemView(item: item)
                            .tag(item)
                            .onAppear {
                                item.loadChildren()
                            }
                    }
                }
            } else {
                content()
            }
        }
        .frame(maxHeight: .infinity)
        .navigationSplitViewColumnWidth(ideal: 260)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    newFile()
                } label: {
                    Image(systemName: "plus")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                .disabled(appState.rootItem == nil)
                Spacer()
            }
            .padding(8)
            .background(.regularMaterial)
        }
        .alert("New Markdown File", isPresented: $isPresented) {
            TextField("File name", text: $newFileName)
            Button("Create", action: createNewFile)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new Markdown file")
        }
        .alert("File Creation", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    func newFile() {
        newFileName = ""
        isPresented = true
    }
    
    func createNewFile() {
        guard let rootItem = rootItem else {
            alertMessage = "No root directory selected"
            showingAlert = true
            return
        }
        
        var fileName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fileName.lowercased().hasSuffix(".md") {
            fileName += ".md"
        }
        
        let newFileURL = rootItem.url.appendingPathComponent(fileName)
        
        do {
            try "".write(to: newFileURL, atomically: true, encoding: .utf8)
            alertMessage = "File created successfully"
            rootItem.loadChildren() // Refresh the file list
        } catch {
            alertMessage = "Error creating file: \(error.localizedDescription)"
        }
        
        showingAlert = true
    }
}

#Preview {
    @State var selection: Set<FileItem> = []
    
    return RequirementsView(rootItem: nil, selection: $selection) {
        Text("No directory loaded")
    }
}
