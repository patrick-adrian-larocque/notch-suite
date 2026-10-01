import Foundation
import Testing

@testable import NotchCore

@Suite struct ShelfStoreTests {
    private func item(_ name: String, kind: ShelfItem.Kind = .file) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/shelf/\(name)"), kind: kind)
    }

    // MARK: Items

    @Test func nameDefaultsToLastPathComponent() {
        let long = "A very long quarterly report name that the UI truncates in the middle.pdf"
        #expect(item(long).name == long)
        let folder = ShelfItem(
            url: URL(fileURLWithPath: "/tmp/shelf/Photos", isDirectory: true),
            kind: .folder(itemCount: 12))
        #expect(folder.name == "Photos")
        #expect(ShelfItem(url: folder.url, name: "Custom", kind: .file).name == "Custom")
    }

    @Test func itemsRoundTripThroughCoding() throws {
        let items = [
            item("a.txt"),
            item("b.png", kind: .image),
            item("c.pdf", kind: .pdf(pageCount: 7)),
            item("d", kind: .folder(itemCount: 3)),
        ]
        let data = try JSONEncoder().encode(items)
        #expect(try JSONDecoder().decode([ShelfItem].self, from: data) == items)
    }

    // MARK: Adding and ordering

    @Test func startsEmpty() {
        let store = ShelfStore()
        #expect(store.isEmpty)
        #expect(store.count == 0)
        #expect(store.draggingOutID == nil)
    }

    @Test func newestItemComesFirst() {
        var store = ShelfStore()
        let a = item("a")
        let b = item("b")
        let c = item("c")
        store.add(a)
        store.add(b)
        store.add(c)
        #expect(store.items == [c, b, a])
        #expect(store.count == 3)
        #expect(!store.isEmpty)
    }

    @Test func batchKeepsItsOrderAtTheFront() {
        let old = item("old")
        var store = ShelfStore(items: [old])
        let a = item("a")
        let b = item("b")
        store.add(contentsOf: [a, b])
        #expect(store.items == [a, b, old])
    }

    @Test func emptyBatchChangesNothing() {
        let a = item("a")
        var store = ShelfStore(items: [a])
        store.add(contentsOf: [])
        #expect(store.items == [a])
    }

    @Test func sameFileReplacesOlderEntryAtTheFront() {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        let again = item("a", kind: .image)
        store.add(again)
        #expect(store.items == [again, b])
    }

    @Test func duplicatesWithinABatchKeepTheFirst() {
        let first = item("a")
        let second = item("a", kind: .image)
        let b = item("b")
        var store = ShelfStore()
        store.add(contentsOf: [first, b, second])
        #expect(store.items == [first, b])
    }

    @Test func initialItemsAreDeduplicated() {
        let newer = item("a")
        let older = item("a")
        let b = item("b")
        let store = ShelfStore(items: [newer, b, older])
        #expect(store.items == [newer, b])
    }

    // MARK: Removing

    @Test func removeTakesOutOneItem() {
        let a = item("a")
        let b = item("b")
        let c = item("c")
        var store = ShelfStore(items: [c, b, a])
        let removed = store.remove(id: b.id)
        #expect(removed == b)
        #expect(store.items == [c, a])
        #expect(store.item(id: b.id) == nil)
        #expect(store.item(id: a.id) == a)
    }

    @Test func removingUnknownItemChangesNothing() {
        let a = item("a")
        var store = ShelfStore(items: [a])
        let removed = store.remove(id: UUID())
        #expect(removed == nil)
        #expect(store.items == [a])
    }

    @Test func removeAllEmptiesTheShelf() {
        let a = item("a")
        var store = ShelfStore(items: [a, item("b")])
        store.beginDragOut(id: a.id)
        store.removeAll()
        #expect(store.isEmpty)
        #expect(store.draggingOutID == nil)
    }

    // MARK: Dragging out

    @Test func dragOutMarksThePlaceholder() {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        let began = store.beginDragOut(id: a.id)
        #expect(began)
        #expect(store.draggingOutID == a.id)
        #expect(store.isDraggingOut(id: a.id))
        #expect(!store.isDraggingOut(id: b.id))
        // The item stays listed while dragged, so the UI can draw its placeholder.
        #expect(store.items == [b, a])
    }

    @Test func dragOutOfUnknownItemIsRefused() {
        var store = ShelfStore(items: [item("a")])
        let began = store.beginDragOut(id: UUID())
        #expect(!began)
        #expect(store.draggingOutID == nil)
    }

    @Test func moveOutRemovesTheItem() {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        store.beginDragOut(id: a.id)
        let ended = store.endDragOut(.moved)
        #expect(ended == a)
        #expect(store.items == [b])
        #expect(store.draggingOutID == nil)
    }

    @Test(arguments: [ShelfDragOutcome.copied, .cancelled])
    func copyOrCancelKeepsTheItem(outcome: ShelfDragOutcome) {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        store.beginDragOut(id: a.id)
        let ended = store.endDragOut(outcome)
        #expect(ended == nil)
        #expect(store.items == [b, a])
        #expect(store.draggingOutID == nil)
    }

    @Test func endingWithoutADragChangesNothing() {
        let a = item("a")
        var store = ShelfStore(items: [a])
        let ended = store.endDragOut(.moved)
        #expect(ended == nil)
        #expect(store.items == [a])
    }

    @Test func newDragReplacesTheOldOne() {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        store.beginDragOut(id: a.id)
        store.beginDragOut(id: b.id)
        let ended = store.endDragOut(.moved)
        #expect(ended == b)
        #expect(store.items == [a])
    }

    @Test func removingTheDraggedItemEndsTheDrag() {
        let a = item("a")
        let b = item("b")
        var store = ShelfStore(items: [b, a])
        store.beginDragOut(id: a.id)
        store.remove(id: a.id)
        #expect(store.draggingOutID == nil)
        let ended = store.endDragOut(.moved)
        #expect(ended == nil)
        #expect(store.items == [b])
    }

    @Test func replacingTheDraggedFileEndsTheDrag() {
        let a = item("a")
        var store = ShelfStore(items: [a])
        store.beginDragOut(id: a.id)
        let again = item("a")
        store.add(again)
        #expect(store.draggingOutID == nil)
        #expect(store.items == [again])
    }

    @Test func addingOtherItemsKeepsTheDrag() {
        let a = item("a")
        var store = ShelfStore(items: [a])
        store.beginDragOut(id: a.id)
        store.add(item("b"))
        #expect(store.draggingOutID == a.id)
    }

    @Test(arguments: [
        (false, false, ShelfDragOutcome.cancelled),
        (false, true, .cancelled),
        (true, false, .moved),
        (true, true, .copied),
    ])
    func outcomeFromDropAndOptionKey(dropped: Bool, copyModifier: Bool, expected: ShelfDragOutcome)
    {
        #expect(ShelfDragOutcome(dropped: dropped, copyModifier: copyModifier) == expected)
    }
}
