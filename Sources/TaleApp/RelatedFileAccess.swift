import Foundation

/// Grants scoped access to SQLite's recovery journal alongside the selected database.
/// See Apple's "Accessing files from the macOS App Sandbox", related file access.
final class SQLiteJournalPresenter: NSObject, NSFilePresenter {
    let primaryPresentedItemURL: URL?
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()

    init(databaseURL: URL) {
        primaryPresentedItemURL = databaseURL
        presentedItemURL = URL(fileURLWithPath: databaseURL.path + "-journal")
        super.init()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
    }

    static func access<T>(for databaseURL: URL, operation: () throws -> T) throws -> T {
        let presenter = SQLiteJournalPresenter(databaseURL: databaseURL)
        NSFileCoordinator.addFilePresenter(presenter)
        defer { NSFileCoordinator.removeFilePresenter(presenter) }
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(writingItemAt: presenter.presentedItemURL!, options: .forMerging,
                               error: &coordinationError) { _ in
            result = Result { try operation() }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }
}
