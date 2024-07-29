//
//  FileItemView.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import SwiftUI

struct FileItemView: View {
        
    let item: FileItem
    
    var body: some View {
        HStack {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundColor(item.isDirectory ? .blue : .gray)
            Text(item.name)
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
    }
}

//#Preview {
//    FileItemView()
//}
