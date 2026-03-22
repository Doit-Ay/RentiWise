import XCTest
@testable import RentiWise

final class StorageURLBuilderTests: XCTestCase {

    func testProjectRefNotEmpty() {
        XCTAssertFalse(StorageURLBuilder.projectRef.isEmpty)
    }

    func testBucketNotEmpty() {
        XCTAssertFalse(StorageURLBuilder.bucket.isEmpty)
    }

    func testBaseURLStringFormat() {
        let base = StorageURLBuilder.baseURLString
        XCTAssertTrue(base.hasPrefix("https://"))
        XCTAssertTrue(base.hasSuffix(".supabase.co"))
    }

    func testPublicFileURLValidPath() {
        let url = StorageURLBuilder.publicFileURL(for: "user-id/image.jpg")
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("/storage/v1/object/public/"))
        XCTAssertTrue(urlString.contains("itemimages"))
        XCTAssertTrue(urlString.contains("user-id/image.jpg"))
    }

    func testPublicFileURLEmptyPath() {
        let url = StorageURLBuilder.publicFileURL(for: "")
        XCTAssertNotNil(url)
        // Empty path still produces a valid URL (ends with the bucket name and /)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("itemimages/"))
    }

    func testPublicFileURLNestedPath() {
        let url = StorageURLBuilder.publicFileURL(for: "owner/folder/image_01.jpg")
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("owner/folder/image_01.jpg"))
    }
}
