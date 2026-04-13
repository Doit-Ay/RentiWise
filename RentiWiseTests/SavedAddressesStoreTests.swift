import XCTest
@testable import RentiWise

final class SavedAddressesStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SavedAddressesStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore(userId: String?) -> SavedAddressesStore {
        SavedAddressesStore(defaults: defaults, currentUserIdProvider: { userId })
    }

    func testSelectedAddressIsScopedPerUser() {
        let firstUserStore = makeStore(userId: "user-a")
        let secondUserStore = makeStore(userId: "user-b")
        let guestStore = makeStore(userId: nil)

        firstUserStore.setDefaultSelectedAddress("12 First Street, Chennai")
        secondUserStore.setDefaultSelectedAddress("98 Second Street, Bengaluru")
        guestStore.setDefaultSelectedAddress("Current Location")

        XCTAssertEqual(firstUserStore.getDefaultSelectedAddress(), "12 First Street, Chennai")
        XCTAssertEqual(secondUserStore.getDefaultSelectedAddress(), "98 Second Street, Bengaluru")
        XCTAssertEqual(guestStore.getDefaultSelectedAddress(), "Current Location")
    }

    func testSavedAddressListsDoNotBleedAcrossAccounts() {
        let firstUserStore = makeStore(userId: "user-a")
        let secondUserStore = makeStore(userId: "user-b")

        firstUserStore.add("12 First Street, Chennai")
        firstUserStore.add("Office, Chennai")
        secondUserStore.add("98 Second Street, Bengaluru")

        XCTAssertEqual(firstUserStore.allAddresses(), ["Office, Chennai", "12 First Street, Chennai"])
        XCTAssertEqual(secondUserStore.allAddresses(), ["98 Second Street, Bengaluru"])
    }

    func testResetOnlyClearsCurrentScope() {
        let firstUserStore = makeStore(userId: "user-a")
        let secondUserStore = makeStore(userId: "user-b")

        firstUserStore.setDefaultSelectedAddress("12 First Street, Chennai")
        secondUserStore.setDefaultSelectedAddress("98 Second Street, Bengaluru")

        firstUserStore.resetToDefault()

        XCTAssertNil(firstUserStore.getDefaultSelectedAddress())
        XCTAssertEqual(secondUserStore.getDefaultSelectedAddress(), "98 Second Street, Bengaluru")
    }
}
