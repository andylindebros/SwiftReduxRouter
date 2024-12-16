@testable import SwiftReduxRouter
import XCTest

final class HelperTests: XCTestCase {
    struct MyModel: Equatable, Codable {
        let someURL: URL?
        let someString: String
        let someInt: Int
        let someNested: [Nested]
    }

    struct Nested: Equatable, Codable {
        var label: String
    }

    func testAddJsonToURLInNavPath() throws {
        let model = MyModel(
            someURL: URL(string: "https://www.example.com?some=value"),
            someString: "Some value",
            someInt: 1,
            someNested: [.init(label: "label")]
        )

        let path = URL(string: "https://test.com/page?filter=cool")!
        let newURL = path.addJSONQueryItem(key: "model", value: model)

        let decodedModel: MyModel? = newURL.queryItem(named: "model")?.decodeJsonAsModel()
        XCTAssertEqual(try XCTUnwrap(decodedModel), model)

    }

    func testCombineNavRoutes() throws {
        let childRoute = NavigationRoute("/items/<int:itemId>", rules: ["itemId": .any], accessLevel: .private)
        let parentRoute = NavigationRoute("/var/<string:foo>", rules: ["foo": .oneOf([.string("foo"), .string("bar")])], accessLevel: .internal)

        let combinedRoute = parentRoute.append(childRoute)

        let comparedRules: [String: NavigationRule] = ["itemId": .any, "foo": .oneOf([.string("foo"), .string("bar")])]

        XCTAssertEqual(combinedRoute.path, "/var/<string:foo>/items/<int:itemId>")
        XCTAssertEqual(combinedRoute.accessLevel, .internal)
        XCTAssertEqual(combinedRoute.rules, comparedRules)

        let reversed = combinedRoute.reverse(params: ["foo": .string("foo"), "itemId": .int(1)])

        XCTAssertEqual(try XCTUnwrap(reversed?.path), "/var/foo/items/1")
    }
}
