import Foundation
import UIKit

enum FileType {
    case audio
    case image
    
    var directory: String {
        switch self {
        case .audio:
            return "VoiceRecords"
        case .image:
            return "Images"
        }
    }
}

class FileManagerService {
    static let shared = FileManagerService()
    private let fileManager = FileManager.default
    
    private init() {
        // 创建必要的目录
        createDirectoryIfNeeded(for: .audio)
        createDirectoryIfNeeded(for: .image)
    }
    
    // MARK: - Directory Management
    
    private func createDirectoryIfNeeded(for type: FileType) {
        guard let directoryURL = getDirectoryURL(for: type) else { return }
        
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating directory for \(type.directory): \(error)")
            }
        }
    }
    
    private func getDirectoryURL(for type: FileType) -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(type.directory)
    }
    
    // MARK: - File Operations
    
    func saveFile(data: Data, withName filename: String, type: FileType) -> URL? {
        guard let directoryURL = getDirectoryURL(for: type) else { return nil }
        let fileURL = directoryURL.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
    
    func loadFile(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Error loading file: \(error)")
            return nil
        }
    }
    
    func deleteFile(at url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func generateUniqueFilename(extension: String) -> String {
        return "\(UUID().uuidString).\(`extension`)"
    }
    
    func saveImage(_ image: UIImage, withName filename: String? = nil) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let imageName = filename ?? generateUniqueFilename(extension: "jpg")
        return saveFile(data: data, withName: imageName, type: .image)
    }
    
    func loadImage(from url: URL) -> UIImage? {
        guard let data = loadFile(from: url) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Audio File Management
    
    func getAudioFileURL(filename: String? = nil) -> URL? {
        guard let directoryURL = getDirectoryURL(for: .audio) else { return nil }
        let audioFilename = filename ?? generateUniqueFilename(extension: "m4a")
        return directoryURL.appendingPathComponent(audioFilename)
    }
    
    func cleanupTempFiles() {
        guard let tempDirectoryURL = try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(
                at: tempDirectoryURL,
                includingPropertiesForKeys: nil
            )
            for fileURL in tempFiles {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Error cleaning temp files: \(error)")
        }
    }
} 