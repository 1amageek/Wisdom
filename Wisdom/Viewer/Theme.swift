//
//  File.swift
//  
//
//  Created by Norikazu Muramoto on 2024/07/21.
//

import Foundation
import CodeEditSourceEditor

extension EditorTheme {
    
    public static var lightMode: EditorTheme {
        EditorTheme(
            text: .init(hex: "000000"),
            insertionPoint: .init(hex: "000000"),
            invisibles: .init(hex: "D6D6D6"),
            background: .init(hex: "FFFFFF"),
            lineHighlight: .init(hex: "EDF5FF"),
            selection: .init(hex: "B2D7FF"),
            keywords: .init(hex: "A90D91"),
            commands: .init(hex: "7B0051"),
            types: .init(hex: "0E6FAB"),
            attributes: .init(hex: "836C28"),
            variables: .init(hex: "2E0D6E"),
            values: .init(hex: "1C00CF"),
            numbers: .init(hex: "1C00CF"),
            strings: .init(hex: "C41A16"),
            characters: .init(hex: "1C00CF"),
            comments: .init(hex: "007400")
        )
    }

    public static var darkMode: EditorTheme {
        EditorTheme(
            text: .init(hex: "FFFFFF"),
            insertionPoint: .init(hex: "FFFFFF"),
            invisibles: .init(hex: "424242"),
            background: .init(hex: "1F1F24"),
            lineHighlight: .init(hex: "2F3239"),
            selection: .init(hex: "515C6A"),
            keywords: .init(hex: "FC5FA3"),
            commands: .init(hex: "FD8F3F"),
            types: .init(hex: "5DD8FF"),
            attributes: .init(hex: "FFB454"),
            variables: .init(hex: "75BFFF"),
            values: .init(hex: "A167E6"),
            numbers: .init(hex: "A167E6"),
            strings: .init(hex: "FC6A5D"),
            characters: .init(hex: "A167E6"),
            comments: .init(hex: "41A1C0")
        )
    }
}
