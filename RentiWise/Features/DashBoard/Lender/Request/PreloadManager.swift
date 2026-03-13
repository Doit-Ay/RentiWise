// PreloadManager.swift
import Foundation
import Supabase
import UIKit

final class PreloadManager {
    static let shared = PreloadManager()

    // Cached data
    private(set) var featuredItems: [Item] = []
    private(set) var lenderRequests: [RequestWithItem] = []
    private(set) var borrowerRequests: [RequestWithItem] = []

    private var preloadTask: Task<Void, Never>?

    private init() {}

    func startPreloading() {
        // Avoid duplicate work
        if preloadTask != nil { return }

        preloadTask = Task(priority: .userInitiated) {
            // 1) Warm up auth/session
            _ = await SupabaseManager.shared.currentUserId()

            // 2) In parallel, fetch featured items and both request lists (if logged in)
            async let featured = self.fetchFeaturedItems()
            async let lender = self.fetchLenderRequests()
            async let borrower = self.fetchBorrowerRequests()

            let (fi, lr, br) = await (featured, lender, borrower)

            await MainActor.run {
                self.featuredItems = fi
                self.lenderRequests = lr
                self.borrowerRequests = br
            }
        }
    }

    func cancelPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
    }

    // MARK: - Fetch helpers
    private func fetchFeaturedItems() async -> [Item] {
        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .limit(6)
                .execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Item].self, from: response.data)
        } catch {
            return []
        }
    }

    private func fetchLenderRequests() async -> [RequestWithItem] {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return [] }
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

    private func fetchBorrowerRequests() async -> [RequestWithItem] {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return [] }
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
}
