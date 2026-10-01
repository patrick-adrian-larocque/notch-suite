import Foundation

/// How a drag out of the shelf ended.
public enum ShelfDragOutcome: Sendable, Hashable {
    /// Dropped somewhere else as a move. The item leaves the shelf.
    case moved
    /// Dropped somewhere else as a copy (Option held). The item stays on the shelf.
    case copied
    /// Not dropped anywhere. The item stays on the shelf.
    case cancelled

    /// The outcome of a drag that was or wasn't dropped, with or without the copy
    /// modifier (Option on macOS) held at the drop.
    public init(dropped: Bool, copyModifier: Bool) {
        if !dropped {
            self = .cancelled
        } else if copyModifier {
            self = .copied
        } else {
            self = .moved
        }
    }
}

/// The items on the shelf, newest first, and the drag out in progress.
///
/// A plain value with no storage or UI attached. The app keeps one in its observable
/// model and saves `items` through a `ShelfStorage`.
///
/// Ordering and duplicates: added items go to the front, so the newest is first. An
/// item whose `url` is already on the shelf replaces the older entry instead of adding
/// a second one, and moves to the front.
///
/// Dragging out: `beginDragOut(id:)` marks the item, which the UI draws as a
/// placeholder while it is dragged. `endDragOut(_:)` then removes it for a move, or
/// keeps it for a copy or a cancelled drag.
public struct ShelfStore: Sendable, Hashable {
    /// The items, newest first.
    public private(set) var items: [ShelfItem]
    /// The item being dragged out, if any.
    public private(set) var draggingOutID: ShelfItem.ID?

    /// Creates a shelf holding `items`, which are taken to be newest first.
    ///
    /// When several items share a `url`, the first (newest) one is kept.
    public init(items: [ShelfItem] = []) {
        self.items = []
        self.draggingOutID = nil
        add(contentsOf: items)
    }

    /// How many items are on the shelf.
    public var count: Int { items.count }

    /// Whether the shelf is empty.
    public var isEmpty: Bool { items.isEmpty }

    /// The item with `id`, if it is on the shelf.
    public func item(id: ShelfItem.ID) -> ShelfItem? {
        items.first { $0.id == id }
    }

    /// Adds `item` at the front, replacing any entry with the same `url`.
    public mutating func add(_ item: ShelfItem) {
        add(contentsOf: [item])
    }

    /// Adds `newItems` at the front in the order given, as one drop of several files.
    ///
    /// Entries already on the shelf with the same `url` as a new item are replaced.
    /// Within `newItems`, the first item for each `url` wins.
    public mutating func add(contentsOf newItems: [ShelfItem]) {
        var seen = Set<URL>()
        let incoming = newItems.filter { seen.insert($0.url).inserted }
        guard !incoming.isEmpty else { return }
        let kept = items.filter { !seen.contains($0.url) }
        if let draggingOutID, !kept.contains(where: { $0.id == draggingOutID }) {
            self.draggingOutID = nil
        }
        items = incoming + kept
    }

    /// Removes the item with `id`, ending its drag out if it had one.
    ///
    /// - Returns: The removed item, or `nil` when no item has `id`.
    @discardableResult
    public mutating func remove(id: ShelfItem.ID) -> ShelfItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        if draggingOutID == id { draggingOutID = nil }
        return items.remove(at: index)
    }

    /// Empties the shelf, ending any drag out.
    public mutating func removeAll() {
        items.removeAll()
        draggingOutID = nil
    }

    /// Whether `id` is the item being dragged out, which the UI shows as a placeholder.
    public func isDraggingOut(id: ShelfItem.ID) -> Bool {
        draggingOutID == id
    }

    /// Starts dragging the item with `id` out of the shelf.
    ///
    /// Only one item drags at a time; starting a new drag replaces the old one.
    ///
    /// - Returns: `false`, changing nothing, when no item has `id`.
    @discardableResult
    public mutating func beginDragOut(id: ShelfItem.ID) -> Bool {
        guard item(id: id) != nil else { return false }
        draggingOutID = id
        return true
    }

    /// Ends the drag out in progress.
    ///
    /// A move removes the item; a copy or a cancelled drag keeps it where it was.
    /// Does nothing when no drag is in progress.
    ///
    /// - Returns: The item that left the shelf, which is non-`nil` only for `.moved`.
    @discardableResult
    public mutating func endDragOut(_ outcome: ShelfDragOutcome) -> ShelfItem? {
        guard let id = draggingOutID else { return nil }
        draggingOutID = nil
        guard outcome == .moved else { return nil }
        return remove(id: id)
    }
}
