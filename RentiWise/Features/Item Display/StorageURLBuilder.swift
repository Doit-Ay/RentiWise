// StorageURLBuilder.swift
import Foundation

enum StorageURLBuilder {
    static let projectRef = "assshmccdkktfxqycufv"
    static let bucket = "itemimages"

    static var baseURLString: String {
        "https://\(projectRef).supabase.co"
    }

    static func publicFileURL(for path: String) -> URL? {
        guard var url = URL(string: "\(baseURLString)/storage/v1/object/public/\(bucket)") else {
            return nil
        }

        let sanitizedPath = path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !sanitizedPath.isEmpty else {
            return URL(string: url.absoluteString + "/")
        }

        for segment in sanitizedPath.split(separator: "/", omittingEmptySubsequences: true) {
            let decodedSegment = String(segment).removingPercentEncoding ?? String(segment)
            url.appendPathComponent(decodedSegment, isDirectory: false)
        }

        return url
    }
}
