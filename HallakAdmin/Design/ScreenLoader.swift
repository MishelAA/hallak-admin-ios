import Foundation
import Observation

/// One screen's data: shows the saved answer at once, then refreshes.
/// State: loading | loaded(answer) | failed(error). A saved answer stays on screen when a refresh fails.
@Observable
@MainActor
final class ScreenLoader<T: Decodable> {
    enum State {
        case loading
        case loaded(Fetched<T>)
        case failed(APIError)
    }

    let endpoint: Endpoint
    private(set) var answer: Fetched<T>?
    private(set) var error: APIError?
    private(set) var isLoading = false

    init(_ endpoint: Endpoint) { self.endpoint = endpoint }

    var state: State {
        if let answer { return .loaded(answer) }
        if let error { return .failed(error) }
        return .loading
    }

    var value: T? { answer?.value }
    /// Offline banner: the answer on screen is a saved one.
    var isOffline: Bool { (answer?.isStale ?? false) || (answer != nil && error?.behaviour == .offline) }

    /// Show the answer of a change (it is the new state of this screen).
    func set(_ value: T) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Formatters.lebanon
        f.dateFormat = "yyyy-MM-dd HH:mm"
        answer = Fetched(value: value, generatedAt: f.string(from: Date()), isStale: false, savedAt: Date())
        error = nil
    }

    /// First appearance: saved answer instantly, then the network.
    func load(_ session: AppSession) async {
        guard let client = session.client else { return }
        if answer == nil, let saved = await client.cached(endpoint, as: T.self) { answer = saved }
        await refresh(session)
    }

    /// Pull to refresh and Retry. Never loops: one request per call.
    func refresh(_ session: AppSession) async {
        guard let client = session.client, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await client.fetch(endpoint, as: T.self)
            answer = fresh
            error = nil
        } catch let e as APIError {
            if await session.handleSessionError(e) { return }
            error = e
        } catch {
            self.error = .offline
        }
    }
}
