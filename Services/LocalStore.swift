import Foundation

final class LocalStore {
    private static let directoryName = "lifeloop"
    private static let legacyDirectoryName = "Spotus"

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        do {
            let data = try Data(contentsOf: fileURL(named: fileName))
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }

    func save<T: Encodable>(_ value: T, to fileName: String) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL(named: fileName), options: [.atomic])
        } catch {
            print("LocalStore save failed: \(error)")
        }
    }

    private func fileURL(named fileName: String) throws -> URL {
        let baseURL = try applicationSupportURL()
        return baseURL.appendingPathComponent(fileName)
    }

    private func applicationSupportURL() throws -> URL {
        let fileManager = FileManager.default
        let rootURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = rootURL.appendingPathComponent(Self.directoryName, isDirectory: true)
        let legacyURL = rootURL.appendingPathComponent(Self.legacyDirectoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: url.path),
           fileManager.fileExists(atPath: legacyURL.path) {
            try? fileManager.copyItem(at: legacyURL, to: url)
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
