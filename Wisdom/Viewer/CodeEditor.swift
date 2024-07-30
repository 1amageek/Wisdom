//
//  MarkdownEditor.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages

struct CodeEditor: View {
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Binding var document: CodeFile
    
    @State private var language: CodeLanguage
    
    @State private var font: NSFont
    
    @State private var cursorPositions: [CursorPosition] = []
    
    @AppStorage("wrapLines") private var wrapLines: Bool = true
    
    @AppStorage("systemCursor") private var useSystemCursor: Bool = false
    
    private let isEditable: Bool
    
    private let undoManager = CEUndoManager()
    
    init(_ document: Binding<CodeFile>, isEditable: Bool = true, font: NSFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)) {
        self._document = document
        self.isEditable = isEditable
        self.font = font
        self.language = Self.detectLanguage(document.wrappedValue)
    }
    
    private static func detectLanguage(_ document: CodeFile) -> CodeLanguage {
        return CodeLanguage.detectLanguageFrom(
            url: document.url,
            prefixBuffer: document.content.getFirstLines(5),
            suffixBuffer: document.content.getLastLines(5)
        )
    }
    
    var body: some View {
        CodeEditSourceEditor(
            $document.content,
            language: language,
            theme: colorScheme == .dark ? EditorTheme.darkMode : EditorTheme.lightMode,
            font: font,
            tabWidth: 4,
            lineHeight: 1.2,
            wrapLines: wrapLines,
            cursorPositions: $cursorPositions,
            useThemeBackground: false,
            useSystemCursor: useSystemCursor
        )
    }
}


//#Preview {
//
//    @State var content: String = "string"
//
//    return CodeEditor($content)
//}
