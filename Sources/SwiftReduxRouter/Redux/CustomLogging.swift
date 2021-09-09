import Foundation

public protocol CustomLogging : CustomStringConvertible {
    var description: String { get }
}
extension CustomLogging {
    public var description: String {
        "\(type(of: self))"
    }
}
