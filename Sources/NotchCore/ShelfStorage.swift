import Foundation

/// Inspects dropped files and keeps the shelf's items between launches.
///
/// Implemented in the app target on top of the file system, ImageIO and PDFKit, so
/// that `NotchCore` stays free of macOS frameworks.
public protocol ShelfStorage: Sendable {
    /// Builds a shelf item for the file or folder at `url`.
    ///
    /// Decides the item's `ShelfItem.Kind`, counting a PDF's pages or a folder's items,
    /// and falls back to `.file` when it can't read them. Throws when nothing exists
    /// at `url`.
    func item(for url: URL) async throws -> ShelfItem

    /// Returns the saved items, newest first, or an empty array when nothing has been
    /// saved yet.
    ///
    /// Throws only when saved items exist but can't be read.
    func load() async throws -> [ShelfItem]

    /// Saves `items`, newest first, replacing whatever was saved before.
    func save(_ items: [ShelfItem]) async throws
}
