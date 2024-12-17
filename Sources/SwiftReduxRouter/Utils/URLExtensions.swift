import Foundation

public extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems
    }

    func queryItem(named name: String) -> URLQueryItem? {
        queryItems?.first(where: { $0.name == name })
    }

    func addJSONQueryItem<Model: Encodable>(key: String, value: Model) throws -> URL {
        guard
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }
        let item = try URLQueryItem.createJSONQueryItem(key: key, value: value)

        components.queryItems = components.queryItems ?? []
        components.queryItems?.append(item)

        guard let url = components.url else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }
        return url
    }

    func addQueryItem(key: String, value: String) throws -> URL {
        guard
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }
        components.queryItems = components.queryItems ?? []
        components.queryItems?.append(URLQueryItem(name: key, value: value))

        guard let url = components.url else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }
        return url
    }

    func setQueryItems(to newValue: [URLQueryItem]) throws -> URL {
        guard
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }

        components.queryItems = newValue

        guard let url = components.url else {
            throw URLQueryItem.URLQueryItemError.invalidURL
        }
        return url
    }
}

public extension URLQueryItem {
    func decodeJsonAsModel<Model: Decodable>() throws -> Model {
        let decoder = JSONDecoder()
        guard
            let value = value?.data(using: .utf8)
        else {
            throw URLQueryItemError.noData
        }
        return try decoder.decode(Model.self, from: value)
    }

    static func createJSONQueryItem<Model: Encodable>(key: String, value: Model) throws -> URLQueryItem {
        let encoder = JSONEncoder()
        let modelData = try encoder.encode(value)
        guard let value = String(data: modelData, encoding: .utf8) else {
            throw URLQueryItemError.noData
        }
        return URLQueryItem(name: key, value: value)
    }

    enum URLQueryItemError: Error {
        case noData
        case invalidURL
    }
}
