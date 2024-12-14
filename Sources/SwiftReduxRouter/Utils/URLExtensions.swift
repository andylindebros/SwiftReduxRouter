import Foundation

public extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems
    }

    func queryItem(named name: String) -> URLQueryItem? {
        queryItems?.first(where: { $0.name == name })
    }

    func addJSONQueryItem<Model: Encodable>(key: String, value: Model) -> URL {
        if
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true),

            let item = URLQueryItem.createJSONQueryItem(key: key, value: value)
        {
            components.queryItems?.append(item)
            return components.url ?? self
        }
        return self
    }

    func addQueryItem(key: String, value: String) -> URL {
        if
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        {
            components.queryItems?.append(URLQueryItem(name: key, value: value))
            return components.url ?? self
        }
        return self
    }

    func setQueryItems(to newValue: [URLQueryItem]) -> URL {
        if
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        {
            components.queryItems = newValue
            return components.url ?? self
        }
        return self
    }
}

public extension URLQueryItem {
    func decodeJsonAsModel<Model: Decodable>() -> Model? {
        let decoder = JSONDecoder()
        if
            let value = value?.data(using: .utf8)
        {
            return try? decoder.decode(Model.self, from: value)
        }
        return nil
    }

    static func createJSONQueryItem<Model: Encodable>(key: String, value: Model) -> URLQueryItem? {
        let encoder = JSONEncoder()
        if
            let modelData = try? encoder.encode(value),
            let value = String(data: modelData, encoding: .utf8)
        {
           return URLQueryItem(name: key, value: value)
        }
        return nil
    }
}
