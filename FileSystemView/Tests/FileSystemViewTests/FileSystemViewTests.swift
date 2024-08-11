import XCTest
import SwiftUI
@testable import FileSystemView

final class FileSystemViewTests: XCTestCase {
    
    private var fileSystem: FileSystem!

    override func setUp() {
        super.setUp()
        fileSystem = FileSystem.shared
    }

    override func tearDown() {
        fileSystem = nil
        super.tearDown()
    }
    
    func testMoveFile() {
        // Arrange
        let originalURL = FileManager.default.temporaryDirectory.appendingPathComponent("originalFile.txt")
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("movedFile.txt")

        // Create a file to move
        FileManager.default.createFile(atPath: originalURL.path, contents: nil, attributes: nil)

        let fileItem = FileItem(url: originalURL)

        // Act
        fileSystem.move(item: fileItem, to: destinationURL)

        // Assert
//        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path), "Original file should be deleted.")
//        
//        // Check if the destination file exists after moving
//        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path), "File should be moved to the new location.")
//        
//        // Check that the new file has been created
//        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path), "File should exist at the destination path.")
//        
        // Cleanup
        try? FileManager.default.removeItem(at: destinationURL)
    }
}
