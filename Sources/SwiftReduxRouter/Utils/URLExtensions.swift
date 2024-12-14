import Foundation

public extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems
    }

    func queryItem(named name: String) -> URLQueryItem? {
        queryItems?.first(where: { $0.name == name })
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
