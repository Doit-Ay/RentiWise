// StorageURLBuilder.swift
import Foundation

enum StorageURLBuilder {
    static let projectRef = "assshmccdkktfxqycufv"
    static let bucket = "itemimages"

    static var baseURLString: String {
        "https://\(projectRef).supabase.co"
    }

    static func publicFileURL(for path: String) -> URL? {
    
        let urlString = "\(baseURLString)/storage/v1/object/public/\(bucket)/\(path)"
        return URL(string: urlString)
    }
}
