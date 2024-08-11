import SwiftUI

struct FileSystemView: View {
    
    @Environment(FileSystem.self) var fileSystem: FileSystem
    
    @State var sections: [FileItemSection]
    
    init(sections: [FileItemSection]) {
        self._sections = State(initialValue: sections)
    }
    
    var body: some View {
        @Bindable var system = fileSystem
        
        List(selection: $system.selection) {
            ForEach(sections) { section in
                Section {
                    OutlineGroup(section.item, children: \.children) { item in
                        FileItemView(item: item)
                            .tag(item)
                            .contextMenu {
                                Button {
                                    fileSystem.delete(item: item)
                                } label: {
                                    Text("Delete")
                                    Image(systemName: "trash")
                                }
                                Button {
                                    fileSystem.copy(item: item, to: item.url)
                                } label: {
                                    Text("Copy")
                                    Image(systemName: "doc.on.doc")
                                }
                                Button {
                                    fileSystem.move(item: item, to: item.url)
                                } label: {
                                    Text("Move")
                                    Image(systemName: "arrow.right")
                                }
                                Button {
                                    fileSystem.rename(item: item, newName: "NewName") // Example new name
                                } label: {
                                    Text("Rename")
                                    Image(systemName: "pencil")
                                }
                            }
                    }
                    .id(section.item)
                } header: {
                    Text(section.name)
                }
                .onAppear { section.item.loadFileItems() }
            }
        }        
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.init(Character(UnicodeScalar(127)))) {
            fileSystem.showingDeleteConfirmation.toggle()
            return .handled
        }
        .alert("Move to Trash", isPresented: $system.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                fileSystem.deleteItems(fileSystem.selection)
            }
        } message: {
            let selectedFiles = fileSystem.selection.filter { !$0.isDirectory }
            if selectedFiles.count == 1 {
                Text("Do you want to move '\(selectedFiles.first!.name)' to the Trash?")
            } else {
                Text("Do you want to move \(selectedFiles.count) items to the Trash?")
            }
        }
    }
}

