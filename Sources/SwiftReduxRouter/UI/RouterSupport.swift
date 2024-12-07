import Foundation

/// A type which can be converted to an URL string.
protocol URLConvertible {
    var urlValue: URL? { get }
    var urlStringValue: String { get }

    /// Returns URL query parameters. For convenience, this property will never return `nil` even if
    /// there's no query string in the URL. This property doesn't take care of the duplicated keys.
    /// For checking duplicated keys, use `queryItems` instead.
    ///
    /// - seealso: `queryItems`
    var queryParameters: [String: String] { get }

    var queryItems: [URLQueryItem]? { get }
}

extension URLConvertible {
    var queryParameters: [String: String] {
        var parameters = [String: String]()
        urlValue?.query?.components(separatedBy: "&").forEach { component in
            guard let separatorIndex = component.firstIndex(of: "=") else { return }
            let keyRange = component.startIndex ..< separatorIndex
            let valueRange = component.index(after: separatorIndex) ..< component.endIndex
            let key = String(component[keyRange])
            let value = component[valueRange].removingPercentEncoding ?? String(component[valueRange])
            parameters[key] = value
        }
        return parameters
    }

    @available(iOS 8, *)
    var queryItems: [URLQueryItem]? {
        return URLComponents(string: urlStringValue)?.queryItems
    }
}

extension String: URLConvertible {
    var urlValue: URL? {
        if let url = URL(string: self) {
            return url
        }
        var set = CharacterSet()
        set.formUnion(.urlHostAllowed)
        set.formUnion(.urlPathAllowed)
        set.formUnion(.urlQueryAllowed)
        set.formUnion(.urlFragmentAllowed)
        return addingPercentEncoding(withAllowedCharacters: set).flatMap { URL(string: $0) }
    }

    var urlStringValue: String {
        return self
    }
}

extension URL: URLConvertible {
    var urlValue: URL? {
        return self
    }

    var urlStringValue: String {
        return absoluteString
    }
}

/// URLMatcher provides a way to match URLs against a list of specified patterns.
///
/// URLMatcher extracts the pattern and the values from the URL if possible.
struct URLMatcher {
    typealias URLPattern = String
    typealias URLValueConverter = (_ pathComponents: [String], _ index: Int) -> URLPathMatchValue?

    let valueConverters: [String: URLValueConverter] = [
        "string": { pathComponents, index in
            URLPathMatchValue.string(pathComponents[index])
        },
        "int": { pathComponents, index in
            if let value = Int(pathComponents[index]) {
                return URLPathMatchValue.int(value)
            }
            return nil
        },
        "float": { pathComponents, index in
            if let value = Float(pathComponents[index]) {
                return URLPathMatchValue.float(value)
            }
            return nil
        },
        "uuid": { pathComponents, index in
            if let value = UUID(uuidString: pathComponents[index]) {
                return URLPathMatchValue.uuid(value)
            }
            return nil
        },
        "path": { pathComponents, index in
            URLPathMatchValue.path(pathComponents[index ..< pathComponents.count].joined(separator: "/"))
        },
    ]

    init() {}

    /// Returns a matching URL pattern and placeholder values from the specified URL and patterns.
    /// It returns `nil` if the given URL is not contained in the URL patterns.
    ///
    /// For example:
    ///
    ///     let result = matcher.match("myapp://user/123", from: ["myapp://user/<int:id>"])
    ///
    /// The value of the `URLPattern` from an example above is `"myapp://user/<int:id>"` and the
    /// value of the `values` is `["id": 123]`.
    ///
    /// - parameter url: The placeholder-filled URL.
    /// - parameter from: The array of URL patterns.
    ///
    /// - returns: A `URLMatchComponents` struct that holds the URL pattern string, a dictionary of
    ///            the URL placeholder values.
    func match(_ url: URLConvertible, from candidates: [URLPattern], ensureComponentsCount: Bool = true) -> URLMatchResult? {
        let url = normalizeURL(url)
        let scheme = url.urlValue?.scheme
        let stringPathComponents = self.stringPathComponents(from: url)

        var results = [URLMatchResult]()

        for candidate in candidates {
            guard scheme == candidate.urlValue?.scheme else { continue }
            if let result = match(stringPathComponents, with: candidate, ensureComponentsCount: ensureComponentsCount) {
                results.append(result)
            }
        }

        return results.max {
            self.numberOfPlainPathComponent(in: $0.pattern) < self.numberOfPlainPathComponent(in: $1.pattern)
        }
    }

    func match(_ stringPathComponents: [String], with candidate: URLPattern, ensureComponentsCount: Bool = true) -> URLMatchResult? {
        let normalizedCandidate = normalizeURL(candidate).urlStringValue
        let candidatePathComponents = pathComponents(from: normalizedCandidate)

        if ensureComponentsCount, !ensurePathComponentsCount(stringPathComponents, candidatePathComponents) {
            return nil
        }

        var urlValues: [String: URLPathMatchValue] = [:]

        let pairCount = min(stringPathComponents.count, candidatePathComponents.count)
        for index in 0 ..< pairCount {
            let result = matchStringPathComponent(
                at: index,
                from: stringPathComponents,
                with: candidatePathComponents
            )

            switch result {
            case let .matches(placeholderValue):
                if let (key, value) = placeholderValue {
                    urlValues[key] = value
                }

            case .notMatches:
                return nil
            }
        }
        let joinedPath = (stringPathComponents.count > 0 ? stringPathComponents[0 ... pairCount - 1] : []).joined(separator: "/")

        let result = URLMatchResult(pattern: candidate, values: urlValues, path: joinedPath.count > 0 ? "/\(joinedPath)" : "")

        return result
    }

    func normalizeURL(_ dirtyURL: URLConvertible) -> URLConvertible {
        guard dirtyURL.urlValue != nil else { return dirtyURL }
        var urlString = dirtyURL.urlStringValue
        urlString = urlString.components(separatedBy: "?")[0].components(separatedBy: "#")[0]
        urlString = replaceRegex(":/{3,}", "://", urlString)
        urlString = replaceRegex("(?<!:)/{2,}", "/", urlString)
        urlString = replaceRegex("(?<!:|:/)/+$", "", urlString)
        return urlString
    }

    func replaceRegex(_ pattern: String, _ repl: String, _ string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return string }
        let range = NSMakeRange(0, string.count)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: repl)
    }

    func ensurePathComponentsCount(
        _ stringPathComponents: [String],
        _ candidatePathComponents: [URLPathComponent]
    ) -> Bool {
        let hasSameNumberOfComponents = (stringPathComponents.count == candidatePathComponents.count)
        let containsPathPlaceholderComponent = candidatePathComponents.contains {
            if case let .placeholder(type, _) = $0, type == "path" {
                return true
            } else {
                return false
            }
        }

        return hasSameNumberOfComponents || (containsPathPlaceholderComponent && stringPathComponents.count > candidatePathComponents.count)
    }

    func stringPathComponents(from url: URLConvertible) -> [String] {
        return url.urlStringValue.components(separatedBy: "/").lazy.enumerated()
            .filter { _, component in !component.isEmpty }
            .filter { index, component in !self.isScheme(index, component) }
            .map { _, component in component }
    }

    private func isScheme(_ index: Int, _ component: String) -> Bool {
        return index == 0 && component.hasSuffix(":")
    }

    func pathComponents(from url: URLPattern) -> [URLPathComponent] {
        return stringPathComponents(from: url).map(URLPathComponent.init)
    }

    func matchStringPathComponent(
        at index: Int,
        from stringPathComponents: [String],
        with candidatePathComponents: [URLPathComponent]
    ) -> URLPathComponentMatchResult {
        let stringPathComponent = stringPathComponents[index]
        let urlPathComponent = candidatePathComponents[index]

        switch urlPathComponent {
        case let .plain(value):
            guard stringPathComponent == value else { return .notMatches }
            return .matches(nil)

        case let .placeholder(type, key):
            guard let type = type, let converter = valueConverters[type] else {
                return .matches((key, .string(stringPathComponent)))
            }
            if let value = converter(stringPathComponents, index) {
                return .matches((key, value))
            } else {
                return .notMatches
            }
        }
    }

    private func numberOfPlainPathComponent(in pattern: URLPattern) -> Int {
        return pathComponents(from: pattern).lazy.filter {
            guard case .plain = $0 else { return false }
            return true
        }.count
    }
}

public enum URLPathMatchValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case float(Float)
    case uuid(UUID)
    case path(String)

    public func value<T>() -> T? {
        switch self {
        case let .string(value):
            return value as? T
        case let .int(value):
            return value as? T
        case let .float(value):
            return value as? T
        case let .uuid(value):
            return value as? T
        case let .path(value):
            return value as? T
        @unknown default:
            return nil
        }
    }
}

/// Represents an URL match result.
struct URLMatchResult {
    /// The url pattern that was matched.
    let pattern: String

    /// The values extracted from the URL placeholder.
    let values: [String: URLPathMatchValue]

    let path: String
}

enum URLPathComponentMatchResult {
    case matches((key: String, value: URLPathMatchValue)?)
    case notMatches
}

enum URLPathComponent {
    case plain(String)
    case placeholder(type: String?, key: String)

    var value: String {
        switch self {
        case let .plain(str):
            return str
        case let .placeholder(_, key):
            return key
        }
    }
}

extension URLPathComponent {
    init(_ value: String) {
        if value.hasPrefix("<"), value.hasSuffix(">") {
            let start = value.index(after: value.startIndex)
            let end = value.index(before: value.endIndex)
            let placeholder = value[start ..< end] // e.g. "<int:id>" -> "int:id"
            let typeAndKey = placeholder.components(separatedBy: ":")
            if typeAndKey.count == 1 { // any-type placeholder
                self = .placeholder(type: nil, key: typeAndKey[0])
            } else if typeAndKey.count == 2 {
                self = .placeholder(type: typeAndKey[0], key: typeAndKey[1])
            } else {
                self = .plain(value)
            }
        } else {
            self = .plain(value)
        }
    }
}

extension URLPathComponent: Equatable {
    static func == (lhs: URLPathComponent, rhs: URLPathComponent) -> Bool {
        switch (lhs, rhs) {
        case let (.plain(leftValue), .plain(rightValue)):
            return leftValue == rightValue

        case let (.placeholder(leftType, leftKey), .placeholder(rightType, key: rightKey)):
            return (leftType == rightType) && (leftKey == rightKey)

        default:
            return false
        }
    }
}
