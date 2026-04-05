// PreloadManager.swift
import Foundation
import Supabase
import UIKit

/// Central preload orchestrator.
/// Starts immediately in AppDelegate and caches featured items + request lists.
/// The animated splash waits on `waitForCompletion(timeout:)` so the user
/// never sees empty cards flash in.
final class PreloadManager {
    static let shared = PreloadManager()

    /// Posted on the main queue when all preloading is done.
    static let didCompleteNotification = Notification.Name("PreloadManagerDidComplete")

    // MARK: - Cached data
    private(set) var featuredItems: [Item] = []
    private(set) var allFetchedItems: [Item] = []      // full list for trending
    private(set) var lenderRequests: [RequestWithItem] = []
    private(set) var borrowerRequests: [RequestWithItem] = []

    /// Whether the user has any listed items (used by listing section to avoid a second query).
    private(set) var userHasListings: Bool? = nil       // nil = not yet checked

    // MARK: - Completion state
    private(set) var isComplete = false
    private var completionContinuations: [CheckedContinuation<Void, Never>] = []
    private let lock = NSLock()

    private var preloadTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start

    func startPreloading() {
        // Avoid duplicate work
        if preloadTask != nil { return }

        preloadTask = Task(priority: .userInitiated) {
            // 1) Warm up auth/session
            let userId = await SupabaseManager.shared.currentUserId()

            // 2) In parallel, fetch everything
            async let featured = self.fetchFeaturedItems()
            async let lender   = self.fetchLenderRequests(userId: userId)
            async let borrower = self.fetchBorrowerRequests(userId: userId)
            async let listings = self.checkUserHasListings(userId: userId)

            let (fi, lr, br, hasListings) = await (featured, lender, borrower, listings)

            await MainActor.run {
                self.allFetchedItems  = fi
                self.featuredItems    = Array(fi.prefix(4))
                self.lenderRequests   = lr
                self.borrowerRequests = br
                self.userHasListings  = hasListings
                self.markComplete()
            }
        }
    }

    func cancelPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
    }

    // MARK: - Completion signaling

    /// Awaits until preloading finishes or the timeout elapses (whichever comes first).
    /// Returns `true` if preload actually completed; `false` if timed out.
    @discardableResult
    func waitForCompletion(timeout: TimeInterval = 4.0) async -> Bool {
        if isComplete { return true }

        // Race: preload completion vs timeout
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    self.lock.lock()
                    if self.isComplete {
                        self.lock.unlock()
                        continuation.resume()
                    } else {
                        self.completionContinuations.append(continuation)
                        self.lock.unlock()
                    }
                }
                return true   // preload finished
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return false  // timed out
            }
            // First to finish wins
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    /// Call once all data is stored.
    private func markComplete() {
        lock.lock()
        isComplete = true
        let waiting = completionContinuations
        completionContinuations.removeAll()
        lock.unlock()

        // Resume anyone awaiting
        for c in waiting { c.resume() }

        NotificationCenter.default.post(name: Self.didCompleteNotification, object: nil)
    }

    // MARK: - Allow re-preloading (e.g. after sign-in/out)

    func reset() {
        cancelPreloading()
        lock.lock()
        isComplete = false
        featuredItems = []
        allFetchedItems = []
        lenderRequests = []
        borrowerRequests = []
        userHasListings = nil
        lock.unlock()
    }

    // MARK: - Fetch helpers

    private func fetchFeaturedItems() async -> [Item] {
        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .limit(20)           // fetch enough for both featured (4) + trending (6)
                .execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Item].self, from: response.data)
        } catch {
            return []
        }
    }

    private func fetchLenderRequests(userId: String?) async -> [RequestWithItem] {
        guard let userId else { return [] }
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day,category)
        """
        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            return try JSONDecoder().decode([RequestWithItem].self, from: response.data)
        } catch {
            return []
        }
    }

    private func fetchBorrowerRequests(userId: String?) async -> [RequestWithItem] {
        guard let userId else { return [] }
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """
        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("borrower_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            return try JSONDecoder().decode([RequestWithItem].self, from: response.data)
        } catch {
            return []
        }
    }

    /// Lightweight HEAD query — only fetches count, no row data.
    private func checkUserHasListings(userId: String?) async -> Bool {
        guard let userId else { return false }
        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("id", head: true, count: .exact)
                .eq("owner_id", value: userId)
                .execute()
            return (response.count ?? 0) > 0
        } catch {
            return false
        }
    }
}
