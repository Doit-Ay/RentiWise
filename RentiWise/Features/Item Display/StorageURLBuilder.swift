// StorageURLBuilder.swift
import Foundation

enum StorageURLBuilder {
    // TODO: Fill in your actual values
    static let projectRef = "assshmccdkktfxqycufv"          // e.g., "abcdefghij"
    static let bucket = "itemimages"              // e.g., "items"

    static var baseURLString: String {
        "https://\(projectRef).supabase.co"
    }

    static func publicFileURL(for path: String) -> URL? {
        // path is like "B17E.../item_1763575596_0.jpg"
        let urlString = "\(baseURLString)/storage/v1/object/public/\(bucket)/\(path)"
        return URL(string: urlString)
    }
}
