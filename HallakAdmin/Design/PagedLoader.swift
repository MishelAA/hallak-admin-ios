import Foundation
import Observation

/// A list screen: page 1 (saved copy first), then the next page when the last row appears.
/// Changing filters reloads from page 1; answers for old filters are dropped.
@Observable
@MainActor
final class PagedLoader<T: Decodable & Identifiable> {
    private(set) var list = PagedList<T>()
    private(set) var error: APIError?
    private(set) var isLoading = false
    private(set) var isStale = false
    private(set) var loadedOnce = false
    private(set) var generatedAt: String?
    private(set) var savedAt: Date?

    /// Query filters (search, status, billing, sort...). Empty values are not sent.
    private(set) var filters: [String: String]
    let perPage: Int
    private let make: (ListQuery) -> Endpoint
    private var generation = 0

    init(perPage: Int = 25, filters: [String: String] = [:], _ make: @escaping (ListQuery) -> Endpoint) {
        self.perPage = perPage
        self.filters = filters
        self.make = make
    }

    var items: [T] { list.items }
    var isEmpty: Bool { loadedOnce && list.items.isEmpty }
    var isOffline: Bool { isStale || (!list.items.isEmpty && error?.behaviour == .offline) }

    func endpoint(page: Int) -> Endpoint { make(ListQuery(page: page, perPage: perPage, filters: filters)) }

    /// New filters → reload from page 1.
    func setFilters(_ new: [String: String], _ session: AppSession) async {
        guard new != filters || !loadedOnce else { return }
        if new != filters {
            filters = new
            list.reset()
            loadedOnce = false
            error = nil
        }
        await reload(session)
    }

    /// Page 1. Shows the saved copy first when the list is empty.
    func reload(_ session: AppSession) async {
        guard let client = session.client else { return }
        generation += 1
        let mine = generation
        let ep = endpoint(page: 1)
        if list.items.isEmpty || !loadedOnce, let saved = await client.cached(ep, as: Page<T>.self), mine == generation {
            apply(saved, generation: mine)
        }
        isLoading = true
        defer { if mine == generation { isLoading = false } }
        do {
            let answer = try await client.fetch(ep, as: Page<T>.self)
            apply(answer, generation: mine)
            error = nil
        } catch let e as APIError {
            guard mine == generation else { return }
            if await session.handleSessionError(e) { return }
            error = e
            loadedOnce = true
        } catch {
            guard mine == generation else { return }
            self.error = .offline
            loadedOnce = true
        }
    }

    /// Infinite scroll: call when a row appears; loads the next page once the last rows show.
    func loadMoreIfNeeded(after item: T, _ session: AppSession) async {
        guard let index = list.items.firstIndex(where: { $0.id == item.id }),
              index >= list.items.count - 3,
              list.canLoadMore, !isLoading, error == nil, let client = session.client else { return }
        let mine = generation
        isLoading = true
        defer { if mine == generation { isLoading = false } }
        do {
            let answer = try await client.fetch(endpoint(page: list.nextPage), as: Page<T>.self)
            apply(answer, generation: mine)
        } catch let e as APIError {
            guard mine == generation else { return }
            if await session.handleSessionError(e) { return }
            error = e
        } catch {
            if mine == generation { self.error = .offline }
        }
    }

    private func apply(_ answer: Fetched<Page<T>>, generation g: Int) {
        guard g == generation else { return }
        list.append(answer.value)
        isStale = answer.isStale
        generatedAt = answer.generatedAt
        savedAt = answer.savedAt
        loadedOnce = true
    }
}
