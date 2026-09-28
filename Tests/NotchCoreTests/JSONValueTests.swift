import Foundation
import Testing

@testable import NotchCore

@Suite struct JSONValueTests {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func decodesEveryJSONKind() throws {
        let value = try decode(
            #"{"n":null,"b":true,"x":1.5,"s":"hi","a":[1,"two"],"o":{"k":false}}"#)
        #expect(
            value
                == .object([
                    "n": .null,
                    "b": .bool(true),
                    "x": .number(1.5),
                    "s": .string("hi"),
                    "a": .array([.number(1), .string("two")]),
                    "o": .object(["k": .bool(false)]),
                ]))
    }

    @Test func accessorsReturnNilForOtherKinds() throws {
        let value = try decode(#""text""#)
        #expect(value.stringValue == "text")
        #expect(value.boolValue == nil)
        #expect(value.numberValue == nil)
        #expect(value.objectValue == nil)
    }

    @Test func doesNotReadNumbersAsBooleans() throws {
        #expect(try decode("1").boolValue == nil)
        #expect(try decode("1") == .number(1))
    }

    @Test func rejectsTruncatedJSON() {
        #expect(throws: (any Error).self) { try decode(#"{"a":"#) }
    }
}
