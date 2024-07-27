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
    
    var content: () -> Content
    
    init(rootItem: FileItem?, selection: Binding<Set<FileItem>>, @ViewBuilder content: @escaping () -> Content) {
        self.rootItem = rootItem
        self._selection = selection
        self.content = content
    }
    
    var body: some View {
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
}


#Preview {
    
    @State var selection: Set<FileItem> = []
    
    return FileSystemView(rootItem: nil, selection: $selection) {
        Text("No directory loaded")
    }

}
