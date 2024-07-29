//
//  SwiftUIView.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import SwiftUI

struct FileSystemView<Content: View>: View {
    
    let rootItem: FileItem?
    
    @Binding var selection: Set<FileItem>
    
    @Environment(AppState.self) var appState: AppState
    
    @State private var isFileTypeSelectionPresented = false
    
    var content: () -> Content
    
    init(rootItem: FileItem?, selection: Binding<Set<FileItem>>, @ViewBuilder content: @escaping () -> Content) {
        self.rootItem = rootItem
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
                .navigationSplitViewColumnWidth(ideal: 260)
            } else {
                content()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    appState.selectDirectory()
                } label: {
                    Image(systemName: "folder")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                Button {
                    isFileTypeSelectionPresented.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(8)
            .background(.regularMaterial)
        }
        .sheet(isPresented: $isFileTypeSelectionPresented) {
            FileTypeSelectionView()
        }
    }
}


#Preview {
    
    @State var selection: Set<FileItem> = []
    
    return FileSystemView(rootItem: nil, selection: $selection) {
        Text("No directory loaded")
    }

}
