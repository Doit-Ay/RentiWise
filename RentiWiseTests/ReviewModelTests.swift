import XCTest
@testable import RentiWise

final class ReviewModelTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Review Decoding

    func testReviewDecodingAllFields() throws {
        let json = """
        {
            "id": "rev-1",
            "item_id": "item-1",
            "reviewer_id": "user-1",
            "rating": 5,
            "review_text": "Excellent!",
            "created_at": "2025-12-01T10:00:00Z"
        }
        """.data(using: .utf8)!

        let review = try makeDecoder().decode(Review.self, from: json)
        XCTAssertEqual(review.id, "rev-1")
        XCTAssertEqual(review.item_id, "item-1")
        XCTAssertEqual(review.reviewer_id, "user-1")
        XCTAssertEqual(review.rating, 5)
        XCTAssertEqual(review.review_text, "Excellent!")
        XCTAssertNotNil(review.created_at)
    }

    func testReviewDecodingNilOptionals() throws {
        let json = """
        {
            "id": "rev-2",
            "item_id": "item-2",
            "reviewer_id": "user-2",
            "rating": 3,
            "review_text": null,
            "created_at": null
        }
        """.data(using: .utf8)!

        let review = try makeDecoder().decode(Review.self, from: json)
        XCTAssertNil(review.review_text)
        XCTAssertNil(review.created_at)
        XCTAssertEqual(review.rating, 3)
    }

    func testReviewDecodingInvalidRatingStillDecodes() throws {
        // The model doesn't enforce rating range at decode time — that's a DB constraint check
        let json = """
        {
            "id": "rev-3",
            "item_id": "item-3",
            "reviewer_id": "user-3",
            "rating": 0,
            "review_text": null,
            "created_at": null
        }
        """.data(using: .utf8)!

        let review = try makeDecoder().decode(Review.self, from: json)
        XCTAssertEqual(review.rating, 0)
    }

    // MARK: - ItemRatingStats

    func testItemRatingStatsWithData() throws {
        let json = """
        {
            "average_rating": 4.3,
            "review_count": 15
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(ItemRatingStats.self, from: json)
        XCTAssertEqual(stats.average_rating, 4.3)
        XCTAssertEqual(stats.review_count, 15)
    }

    func testItemRatingStatsNoReviews() throws {
        let json = """
        {
            "average_rating": null,
            "review_count": 0
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(ItemRatingStats.self, from: json)
        XCTAssertNil(stats.average_rating)
        XCTAssertEqual(stats.review_count, 0)
    }

    func testItemRatingStatsPerfectScore() throws {
        let json = """
        {
            "average_rating": 5.0,
            "review_count": 1
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(ItemRatingStats.self, from: json)
        XCTAssertEqual(stats.average_rating, 5.0)
        XCTAssertEqual(stats.review_count, 1)
    }
}
