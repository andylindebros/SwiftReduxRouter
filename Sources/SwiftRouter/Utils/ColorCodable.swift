import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

#if os(iOS)
    public extension Decodable where Self: UIColor {
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let components = try container.decode([CGFloat].self)
            self = Self(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        }
    }

    public extension Encodable where Self: UIColor {
        func encode(to encoder: Encoder) throws {
            var r, g, b, a: CGFloat
            (r, g, b, a) = (0, 0, 0, 0)
            var container = encoder.singleValueContainer()
            getRed(&r, green: &g, blue: &b, alpha: &a)
            try container.encode([r, g, b, a])
        }
    }

    extension UIColor: Codable {}
#endif

extension Color: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let (r, g, b, a) = try colorComponents()
        try container.encode([r, g, b, a])
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let components = try container.decode([CGFloat].self)
        self = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }
}

extension Color {
    #if os(macOS)
        typealias SystemColor = NSColor
    #else
        typealias SystemColor = UIColor
    #endif

    func colorComponents() throws -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if os(macOS)
            SystemColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        // Note that non RGB color will raise an exception, that I don't now how to catch because it is an Objc exception.
        #else
            guard SystemColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
                // Pay attention that the color should be convertible into RGB format
                // Colors using hue, saturation and brightness won't work
                throw NSError(domain: "Not a valid RGB color", code: 1)
            }
        #endif

        return (r, g, b, a)
    }
}
