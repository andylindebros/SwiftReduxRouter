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

        let decodedModel: MyModel? = newURL?.queryItem(named: "model")?.decodeJsonAsModel()
        XCTAssertEqual(try XCTUnwrap(decodedModel), model)

    }
}
