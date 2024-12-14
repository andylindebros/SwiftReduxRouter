import Foundation

public extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems
    }

    func queryItem(named name: String) -> URLQueryItem? {
        queryItems?.first(where: { $0.name == name })
    }

    func addJSONQueryItem<Model: Encodable>(key: String, value: Model) -> URL? {
        let encoder = JSONEncoder()
        if
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let modelData = try? encoder.encode(value),
            let value = String(data: modelData, encoding: .utf8)
        {
            components.queryItems?
                .append(URLQueryItem(name: key, value: value))
            return components.url
        }
        return self
    }

    func addQueryItem(key: String, value: String) -> URL? {
        if
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        {
            components.queryItems?.append(URLQueryItem(name: key, value: value))
            return components.url
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
}
