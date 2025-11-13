import Foundation

public protocol UserDefaultsProvider {
    func set(_ value: Any?, forKey defaultName: String)
    func data(forKey defaultName: String) -> Data?
    func removeObject(forKey: String)
}

extension UserDefaults: UserDefaultsProvider {}
