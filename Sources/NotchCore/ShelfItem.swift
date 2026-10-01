import Foundation

/// A file, image, PDF or folder kept on the shelf.
public struct ShelfItem: Sendable, Hashable, Identifiable, Codable {
    /// What the item is, which decides its preview.
    ///
    /// `ShelfStorage` decides the kind when it inspects a dropped file, and falls back
    /// to `.file` when it can't read an image, PDF or folder.
    public enum Kind: Sendable, Hashable, Codable {
        /// Any file without a richer preview.
        case file
        /// An image, previewed as a thumbnail.
        case image
        /// A PDF, previewed as a thumbnail with its page count.
        case pdf(pageCount: Int)
        /// A folder, shown with the number of items directly inside it.
        case folder(itemCount: Int)
    }

    /// Identifies this entry on the shelf. Two drops of the same file get different ids.
    public let id: UUID
    /// Where the item is on disk.
    public var url: URL
    /// The full display name.
    ///
    /// Shortening a long name (the design truncates in the middle and shows the full
    /// name on hover) is up to the UI; the model always keeps the whole name.
    public var name: String
    /// What the item is.
    public var kind: Kind

    /// Creates an item. `name` defaults to the last path component of `url`.
    public init(id: UUID = UUID(), url: URL, name: String? = nil, kind: Kind) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.kind = kind
    }
}
