// "Delete account and public content" (spec §40.4; Web: account-deletion.ts):
// list every post any stored root controls, revoke each with its derived
// control key, verify nothing remains, delete the encrypted vault, then the
// caller asks Core to delete the account. Core never queries Community by
// account; Community sees only cryptographic proofs. A resumable checklist
// keeps partial progress honest.

import Foundation

public struct DeletionChecklist: Codable, Sendable, Equatable {
    public var startedAt: Int64
    public var postsFound = 0
    public var postsRevoked = 0
    public var failedPosts: [String] = []
    public var vaultDeleted = false
    public var accountDeleted = false
    public init(startedAt: Int64) { self.startedAt = startedAt }
}

public enum DeletionOutcome: Sendable, Equatable {
    case done(DeletionChecklist)
    /// This device cannot unlock the roots: nothing was deleted.
    case vaultLocked
    case partial(DeletionChecklist)
}

public protocol DeletionChecklistStore: Sendable {
    func readChecklist() -> DeletionChecklist?
    func writeChecklist(_ checklist: DeletionChecklist?)
}

public actor AccountDeletion {
    private let publish: PublishClient
    private let controls: PostControls
    private let store: DeletionChecklistStore
    private let now: @Sendable () -> Int64

    public init(publish: PublishClient, controls: PostControls, store: DeletionChecklistStore, now: @escaping @Sendable () -> Int64 = { HOneyClock.now().epochMillis }) {
        self.publish = publish
        self.controls = controls
        self.store = store
        self.now = now
    }

    /// Steps 1–3: revoke public content by proof, verify, delete the vault.
    public func deletePublicContent(account: String) async throws -> DeletionOutcome {
        let status = try await controls.status(account: account)
        if case .restoreNeeded = status { return .vaultLocked }
        var checklist = store.readChecklist() ?? DeletionChecklist(startedAt: now())
        if case .none = status {} else {
            let posts = try await publish.listOwnedPosts(account: account)
            checklist.postsFound = posts.count
            checklist.failedPosts = []
            for post in posts {
                do {
                    try await publish.revoke(account: account, post: post)
                    checklist.postsRevoked += 1
                } catch {
                    checklist.failedPosts.append(post.id)
                }
                store.writeChecklist(checklist)
            }
            let remaining = try await publish.listOwnedPosts(account: account)
            if !remaining.isEmpty {
                checklist.failedPosts = Array(Set(checklist.failedPosts + remaining.map(\.id))).sorted()
                store.writeChecklist(checklist)
                return .partial(checklist)
            }
        }
        do {
            try await controls.deleteEverywhere(account: account)
            checklist.vaultDeleted = true
        } catch {
            store.writeChecklist(checklist)
            return .partial(checklist)
        }
        store.writeChecklist(checklist)
        return .done(checklist)
    }

    public func markAccountDeleted() {
        var checklist = store.readChecklist() ?? DeletionChecklist(startedAt: now())
        checklist.accountDeleted = true
        store.writeChecklist(nil)
        _ = checklist
    }
}
