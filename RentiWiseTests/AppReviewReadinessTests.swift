import Foundation
import Testing
@testable import RentiWise

struct AppReviewReadinessTests {

    @Test func infoPlistContainsSpecificUserFacingPermissionStrings() throws {
        let bundle = Bundle(for: AppDelegate.self)

        let camera = try #require(bundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String)
        #expect(camera.localizedCaseInsensitiveContains("item"))
        #expect(camera.localizedCaseInsensitiveContains("damage"))

        let photos = try #require(bundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String)
        #expect(photos.localizedCaseInsensitiveContains("listing"))
        #expect(photos.localizedCaseInsensitiveContains("damage"))

        let location = try #require(bundle.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String)
        #expect(location.localizedCaseInsensitiveContains("nearby"))
        #expect(location.localizedCaseInsensitiveContains("while the app is open"))
    }

    @Test func infoPlistDoesNotRequestBackgroundLocation() {
        let bundle = Bundle(for: AppDelegate.self)
        #expect(bundle.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") == nil)
    }

    @Test func termsOfServiceCoversAppReviewCriticalClauses() {
        let body = LegalDocument.termsOfService.body.lowercased()

        for phrase in ["damage", "non-return", "dispute", "refund", "liability"] {
            #expect(body.contains(phrase))
        }
    }

    @Test func privacyPolicyExplainsDeletionAndPaymentIdentifiers() {
        let body = LegalDocument.privacyPolicy.body.lowercased()

        #expect(body.contains("delete your account"))
        #expect(body.contains("upi"))
        #expect(body.contains("supabase"))
    }
}
