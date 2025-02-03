import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
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
