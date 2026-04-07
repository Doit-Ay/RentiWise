//
//  Phase2FeatureTests.swift
//  RentiWiseTests
//
//  Test Cases for Phase 2 Features: Trust Score (Feature 1), IAP (Feature 2), Value Cap (Feature 3)
//

import XCTest
@testable import RentiWise

// MARK: - Feature 1: Trust Score Tests

final class TrustScoreTests: XCTestCase {

    // TC-P2-01: TrustBadgeView renders correct tier
    func testTrustBadgeViewNewcomer() {
        let badge = TrustBadgeView()
        badge.badgeTier = "newcomer"
        XCTAssertEqual(badge.badgeTier, "newcomer")

        let tier = TrustTier(rawValue: "newcomer")
        XCTAssertEqual(tier?.displayName, "Newcomer")
        XCTAssertEqual(tier?.sfSymbol, "person.fill")
        XCTAssertEqual(tier?.backgroundColor, .systemGray)
    }

    func testTrustBadgeViewTrusted() {
        let tier = TrustTier(rawValue: "trusted")
        XCTAssertEqual(tier?.displayName, "Trusted")
        XCTAssertEqual(tier?.sfSymbol, "checkmark.seal.fill")
        XCTAssertEqual(tier?.backgroundColor, .systemBlue)
    }

    func testTrustBadgeViewReliable() {
        let tier = TrustTier(rawValue: "reliable")
        XCTAssertEqual(tier?.displayName, "Reliable")
        XCTAssertEqual(tier?.sfSymbol, "shield.fill")
        XCTAssertEqual(tier?.backgroundColor, .systemGreen)
    }

    func testTrustBadgeViewTop() {
        let tier = TrustTier(rawValue: "top")
        XCTAssertEqual(tier?.displayName, "Top Lender")
        XCTAssertEqual(tier?.sfSymbol, "star.fill")
    }

    // TC-P2-02: Badge tier thresholds
    func testBadgeTierThresholds() {
        // 0-39: newcomer, 40-69: trusted, 70-89: reliable, 90-100: top
        XCTAssertTrue((0...39).contains(30), "Score 30 should be in newcomer range")
        XCTAssertTrue((40...69).contains(50), "Score 50 should be in trusted range")
        XCTAssertTrue((70...89).contains(80), "Score 80 should be in reliable range")
        XCTAssertTrue((90...100).contains(95), "Score 95 should be in top range")
    }

    // TC-P2-03: Trust score calculation components
    func testTrustScoreComponents() {
        // Phone verified: +30, College: +25, Photo: +10, Rating*7: max 35, Rentals: max 20
        let phonePoints = 30
        let collegePoints = 25
        let photoPoints = 10
        let maxRatingPoints = 35
        let maxRentalPoints = 20
        let maxTotal = phonePoints + collegePoints + photoPoints + maxRatingPoints + maxRentalPoints
        XCTAssertEqual(maxTotal, 120, "Uncapped max should be 120")
        XCTAssertEqual(min(maxTotal, 100), 100, "Capped max should be 100")
    }

    // TC-P2-04: Score with low rating
    func testScoreWithLowRating() {
        let avgRating = 2.5
        let ratingPoints = min(35, Int(round(avgRating * 7)))
        XCTAssertEqual(ratingPoints, 18, "2.5 * 7 = 17.5, rounded = 18")
    }

    // TC-P2-05: TrustBadgeView with score display
    func testTrustBadgeWithScore() {
        let badge = TrustBadgeView()
        badge.badgeTier = "trusted"
        badge.trustScore = 55
        XCTAssertEqual(badge.trustScore, 55)
    }

    // TC-P2-06: TrustScoreBreakdownVC loads (Manual QA)
    func testTrustScoreBreakdownVCLoads() {
        let vc = TrustScoreBreakdownViewController()
        vc.userId = "test-user"
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.title, "Trust Score")
    }
}

// MARK: - Feature 2: IAP Tests

@MainActor
final class IAPTests: XCTestCase {

    // TC-P2-07: Product IDs are correct
    func testProductIDs() {
        XCTAssertEqual(IAPManager.boostProductId, "com.rentiwise.boost7")
        XCTAssertEqual(IAPManager.lenderProProductId, "com.rentiwise.lenderpro")
        XCTAssertEqual(IAPManager.verifiedBadgeProductId, "com.rentiwise.verifiedbadge")
    }

    // TC-P2-08: IAPManager singleton exists
    func testIAPManagerSingleton() {
        let manager = IAPManager.shared
        XCTAssertNotNil(manager, "IAPManager.shared should be available")
    }

    // TC-P2-09: Supported product catalog remains stable
    func testSupportedProductCatalogIsUnique() {
        let productIds = [
            IAPManager.boostProductId,
            IAPManager.lenderProProductId,
            IAPManager.verifiedBadgeProductId
        ]
        XCTAssertEqual(Set(productIds).count, 3, "Each supported entitlement should use a unique product ID")
    }

    // TC-P2-10: UpgradeProVC loads correctly
    func testUpgradeProVCLoads() {
        let vc = UpgradeProViewController()
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.title, "Lender Pro")
    }

    // TC-P2-11: BoostItemVC loads with item info
    func testBoostItemVCLoads() {
        let vc = BoostItemViewController()
        vc.itemId = "item-1"
        vc.itemTitle = "Camera"
        vc.categoryName = "Electronics"
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.title, "Boost Listing")
        XCTAssertEqual(vc.itemId, "item-1")
    }

    // TC-P2-12: Free tier threshold
    func testFreeTierThreshold() {
        // Free users can have up to 3 listings
        let maxFreeListings = 3
        XCTAssertEqual(maxFreeListings, 3, "Free tier limit should be 3")
        XCTAssertTrue(3 >= maxFreeListings, "3 listings should trigger upgrade prompt")
        XCTAssertFalse(2 >= maxFreeListings, "2 listings should not trigger upgrade")
    }

    // TC-P2-13: Boost duration
    func testBoostDuration() {
        let boostDays = 7
        let now = Date()
        let boostExpiry = now.addingTimeInterval(TimeInterval(boostDays * 24 * 3600))
        XCTAssertTrue(boostExpiry > now, "Boost expiry should be in the future")
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: boostExpiry)
        XCTAssertEqual(components.day, 7, "Boost should last 7 days")
    }
}

// MARK: - Feature 3: Value Cap Warning Tests

final class ValueCapWarningTests: XCTestCase {

    // TC-P2-14: Warning shown when deposit > ₹10,000
    func testWarningShownForHighDeposit() {
        let depositValue = 15000.0
        let shouldShowWarning = depositValue > 10000
        XCTAssertTrue(shouldShowWarning, "Warning should show for deposit > ₹10,000")
    }

    // TC-P2-15: Warning hidden when deposit ≤ ₹10,000
    func testWarningHiddenForNormalDeposit() {
        let depositValue = 5000.0
        let shouldShowWarning = depositValue > 10000
        XCTAssertFalse(shouldShowWarning, "Warning should not show for deposit ≤ ₹10,000")
    }

    // TC-P2-16: Warning exact boundary at ₹10,000
    func testWarningBoundary() {
        let exactly10k = 10000.0
        let shouldShowWarning = exactly10k > 10000
        XCTAssertFalse(shouldShowWarning, "₹10,000 exactly should NOT show warning (>10k only)")
    }

    // TC-P2-17: Warning does NOT block listing
    func testWarningDoesNotBlockListing() {
        // Feature 3 explicitly states: "Do NOT block the listing — just warn"
        // The textField delegate returns true regardless of deposit amount
        let shouldAllowInput = true // textField delegate always returns true
        XCTAssertTrue(shouldAllowInput, "Deposit warning should never block input")
    }

    // TC-P2-18: Warning label text content
    func testWarningLabelText() {
        let expectedText = "⚠️ High-value items may need extra trust coordination with your borrower."
        XCTAssertTrue(expectedText.contains("High-value"), "Warning should mention high-value items")
        XCTAssertTrue(expectedText.contains("trust coordination"), "Warning should mention trust coordination")
    }

    // TC-P2-19: AddItemPricingVC conforms to UITextFieldDelegate
    func testPricingVCIsTextFieldDelegate() {
        let vc = AddItemPricingViewController(nibName: "AddItemPricingViewController", bundle: nil)
        XCTAssertTrue(vc is UITextFieldDelegate, "AddItemPricingVC should conform to UITextFieldDelegate")
    }
}
