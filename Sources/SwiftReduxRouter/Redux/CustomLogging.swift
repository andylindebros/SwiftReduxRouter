import Foundation

public protocol CustomLogging: CustomStringConvertible {
    var description: String { get }
}

public extension CustomLogging {
    var description: String {
        "\(type(of: self))"
    }
}
