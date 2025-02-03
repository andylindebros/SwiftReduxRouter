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
        guard
            let cgColor
        else {
            throw CodableColor.CodingError.wrongColor
        }
        var container = encoder.singleValueContainer()

        try container.encode(CodableColor(cgColor: cgColor))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let codableColor = try container.decode(CodableColor.self)
        self = Color(cgColor: codableColor.cgColor)
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

public struct CodableColor: Codable {
    let cgColor: CGColor

    enum CodingKeys: String, CodingKey {
        case colorSpace
        case components
    }

    public init(cgColor: CGColor) {
        self.cgColor = cgColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder
            .container(keyedBy: CodingKeys.self)
        let colorSpace = try container
            .decode(String.self, forKey: .colorSpace)
        let components = try container
            .decode([CGFloat].self, forKey: .components)

        guard
            let cgColorSpace = CGColorSpace(name: colorSpace as CFString),
            let cgColor = CGColor(
                colorSpace: cgColorSpace, components: components
            )
        else {
            throw CodingError.wrongData
        }

        self.cgColor = cgColor
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard
            let colorSpace = cgColor.colorSpace?.name,
            let components = cgColor.components
        else {
            throw CodingError.wrongData
        }

        try container.encode(colorSpace as String, forKey: .colorSpace)
        try container.encode(components, forKey: .components)
    }

    enum CodingError: Error {
        case wrongColor
        case wrongData
    }
}
